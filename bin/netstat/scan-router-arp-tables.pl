#!/usr/bin/perl

# Begin-Doc
# Name: scan-router-arp-tables.pl
# Type: script
# Description: scan and record content of router arp tables for arpscan reports
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::OracleObject;
use Local::SetUID;
use Local::AuthSrv;

use lib "/local/netdb/libs";
use NetMaint::LastTouch;
use NetMaint::DB;

use Net::SNMP;
use Net::SSH::Perl;
use Time::HiRes qw(time);

&SetUID("netdb");

# Home dir for SSH
$ENV{HOME} = "/local/netdb";

my $debug = 1;
alarm(600);

open( my $ps, "-|" ) || exec( "/bin/ps", "auxwww" );
while ( my $line = <$ps> ) {
    my @tmp = split( ' ', $line );
    if ( $line =~ /perl/ && $line =~ /scan-router-arp-tables\.pl/ ) {
        if ( $tmp[1] != $$ ) {
            print "Exiting, another scan-router-arp-tables process running.\n";
            exit;
        }
    }
}
close($ps);

my $touch = new NetMaint::LastTouch;

print "Preloading ip touch cache...\n";
$touch->PreLoadCache("ip");
print "Done.\n";

print "Preloading ether touch cache...\n";
$touch->PreLoadCache("ether");
print "Done.\n";

my $db = new NetMaint::DB
    || print "failed to open db!" && die;

# Now build up the list of switches
my $qry     = "select distinct host from admin_host_options where config='# DOES_ARPSCAN'";
my $cid     = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
my @hosts   = ();
my %routers = ();
while ( my ($router) = $db->SQL_FetchRow($cid) ) {
    $router =~ s/\.network\.mst\.edu$//go;
    $routers{$router} = "snmp";
}
$db->SQL_CloseQuery($cid);

#
# hardwire the SSH ones
#
$routers{"nccs-01"} = "ssh";
$routers{"ncpk-01"} = "ssh";

my @routers = sort keys %routers;
if ( $ARGV[0] ne "" ) {
    @routers = ();
    foreach my $arg (@ARGV) {
        $arg = lc $arg;
        foreach my $rtr ( keys(%routers) ) {
            if ( index( $rtr, $arg ) >= 0 ) {
                push( @routers, $rtr );
            }
        }
    }
}

my $insqry = "insert into arpscan (ether,ip,tstamp,router,latest) values (?,?,now(),?,1)";
my $inscid = $db->SQL_OpenBoundQuery($insqry)
    || $db->SQL_Error("open $insqry") && die;

my $updqry = "update arpscan set tstamp=now(),latest=1 where ether=? and ip=? and router=?";
my $updcid = $db->SQL_OpenBoundQuery($updqry)
    || $db->SQL_Error("open $updqry") && die;

my $selqry = "select ether, ip, unix_timestamp(now())-unix_timestamp(tstamp) from arpscan where latest=1 and router=?";
my $selcid = $db->SQL_OpenBoundQuery($selqry)
    || $db->SQL_Error("open $selqry") && die;

my $updrowqry = "update arpscan set latest=0,tstamp=now() where router=? and ether=? and ip=? and latest != 0";
my $updrowcid = $db->SQL_OpenBoundQuery($updrowqry)
    || $db->SQL_Error("open $updrowqry") && die;

my $cnt     = 0;
my $skipcnt = 0;
foreach my $router (@routers) {

    print "Processing $router.\n";

    print "  Scanning existing latest entries for $router in database.\n";
    $db->SQL_ExecQuery( $selcid, $router )
        || $db->SQL_Error( $selqry . " ($router)" ) && next;
    my @have_data = ();
    my %have_key  = ();
    my $tcnt      = 0;
    while ( my ( $ether, $ip, $age ) = $db->SQL_FetchRow($selcid) ) {
        $have_key{ $ether . "\0" . $ip } = $age;
        push( @have_data, [ $ether, $ip ] );
        $tcnt++;
    }
    print "  Retrieved $tcnt existing records.\n";

    my $table;
    if ( $routers{$router} eq "ssh" ) {
        $table = &GetARPTable_SSH($router);
    }
    else {
        $table = &GetARPTable_SNMP($router);
    }
    if ( !$table ) {
        print "  Skipping $router, table fetch failed.\n";
        next;
    }
    if ( $table && scalar(@$table) == 0 ) {
        print "  Table retrieved but empty. Skipping $router.\n";
        next;
    }
    print "  Table retrieved. Record count = ", scalar(@$table), "\n";

    my %want_key = ();
    my $tcnt     = 0;
    my $tskipcnt = 0;
    print "  Processing table from $router.\n";
    foreach my $row (@$table) {
        my ( $ether, $ip ) = @$row;
        next if ( $ether eq "0" x 16 );
        next if ( $ether eq "F" x 16 );

        $cnt++;
        $tcnt++;

        if ( $cnt % 250 == 0 ) { print "    $cnt\n"; }

        my $key = $ether . "\0" . $ip;

        # Update always
        $touch->UpdateLastTouch( ether => $ether, ip => $ip );

        # if it's already in the table and listed as active with an age less than 2 days, skip it
        $want_key{$key} = 1;
        if ( $have_key{$key} && $have_key{$key} < 2 * 24 * 60 * 60 ) {
            $skipcnt++;
            $tskipcnt++;
            next;
        }

        if ( !$have_key{$key} ) {
            $db->SQL_ExecQuery( $updcid, $ether, $ip, $router )
                || $db->SQL_Error( $updqry . " ($ether,$ip,$router)" );
            if ( $db->SQL_RowCount() == 0 ) {
                $debug
                    && print "  Inserting new entry $ether/$ip on $router.\n";
                $db->SQL_ExecQuery( $inscid, $ether, $ip, $router )
                    || $db->SQL_Error( $insqry . " ($ether,$ip,$router)" ) && next;
            }
        }
        else {
            $debug && print "  Marking new entry $ether/$ip on $router.\n";
            $db->SQL_ExecQuery( $updcid, $ether, $ip, $router )
                || $db->SQL_Error( $updqry . " ($ether,$ip,$router)" );
        }

    }
    print "  Processed $tcnt records, skipped $tskipcnt records.\n";

    # Scan through existing records and change any that are no longer active
    foreach my $row (@have_data) {
        my ( $ether, $ip ) = @$row;
        my $key = $ether . "\0" . $ip;
        if ( !$want_key{$key} ) {
            $debug && print "  Marking old entry $ether/$ip on $router.\n";
            $db->SQL_ExecQuery( $updrowcid, $router, $ether, $ip )
                || $db->SQL_Error( $updrowqry . " ($router,$ether,$ip)" ) && next;
            if ( $db->SQL_RowCount() == 0 ) {
                print "didn't update any rows, why???\n";
            }
        }
    }
}
print "Total records processed: $cnt\n";
print "Total records skipped: $skipcnt\n";

$db->SQL_CloseQuery($updrowcid);
$db->SQL_CloseQuery($selcid);
$db->SQL_CloseQuery($updcid);
$db->SQL_CloseQuery($inscid);

print "Done with ARP scan/update.\n";

# Begin-Doc
# Name: GetARPTable_SNMP
# Syntax: $table = &GetARPTable_SNMP($host);
# Description: retrieve arp table from host via snmp
# End-Doc
sub GetARPTable_SNMP {
    my $router = shift;
    my $table  = [];

    my $community = "monitor";

    my $baseoid = "1.3.6.1.2.1.3.1.1.2";

    print "  Fetching ARP table from $router via SNMP.\n";
    my ( $session, $error ) = Net::SNMP->session(
        -translate => [ -octetstring => 0x0 ],
        -hostname  => $router,
        -community => $community,
        -version   => "snmpv2c",
    );

    if ( !$session ) {
        print "    Error: failed to establish session.\n";
        return undef;
    }

    my $stime = time;
    my $resp  = $session->get_table($baseoid);
    my $etime = time;
    print "    Table Fetch Time: ", $etime - $stime, "\n";

    if ( $session->error ) {
        print "    Error: ", $session->error, "\n";
        return undef;
    }

    foreach my $key ( keys(%$resp) ) {
        my $ether = uc sprintf( "%s%s%s%s%s%s", unpack( 'H2' x 6, $$resp{$key} ) );

        if ( $key =~ /(\d+\.\d+\.\d+\.\d+)$/o ) {
            my $ip = $1;
            push( @$table, [ $ether, $ip ] );
        }
    }

    return $table;
}

# Begin-Doc
# Name: GetARPTable_SSH
# Syntax: $table = &GetARPTable_SSH($host);
# Description: retrieve arp table from host via ssh
# End-Doc
sub GetARPTable_SSH {
    my $router = shift;
    my $table  = [];

    my $pw = &AuthSrv_Fetch( user => "netdb", instance => "ads" )
        || warn "couldn't get netdb pw" && return undef;

    print "  Fetching ARP table from $router via SSH.\n";
    my $ssh;
    eval { $ssh = Net::SSH::Perl->new($router); };
    if ( !$ssh ) {
        print "    Error: failed to connect to $router via SSH.\n";
        return undef;
    }

    my $stime = time;
    my $res;
    eval { $res = $ssh->login( "netdb", $pw ) };
    if ( !$res ) {
        print "    Error: failed to login to $router\n";
        return undef;
    }
    print "   Sending show ip arp.\n";
    my ( $stdout1, $stderr1, $exit1 ) = $ssh->cmd("show ip arp");
    print "   Sending show ip arp vrf SEC.\n";
    my ( $stdout2, $stderr2, $exit2 ) = $ssh->cmd("show ip arp vrf SEC");
    print "   Sending show ip arp vrf VOIP.\n";
    my ( $stdout3, $stderr3, $exit3 ) = $ssh->cmd("show ip arp vrf VOIP");
    my $stdout = $stdout1 . "\n" . $stdout2 . "\n" . $stdout3;
    undef $ssh;

    my $etime = time;
    print "    Table Fetch Time: ", $etime - $stime, "\n";

    foreach my $line ( split( /[\r\n]+/, $stdout ) ) {
        if ( $line =~ m|Internet\s+(\d+\.\d+\.\d+\.\d+)\s+.*?\s+([a-f0-9]{4}\.[a-f0-9]{4}\.[a-f0-9]{4})\s+ARPA|o ) {
            my $ip    = $1;
            my $ether = uc($2);
            $ether =~ s/\.//g;

            push( @$table, [ $ether, $ip ] );
        }
    }

    return $table;
}

