#!/usr/bin/perl

# Begin-Doc
# Name: update-switch-mac-block-list.pl
# Type: script
# Description: updates mac blocking table on switch
# End-Doc

use strict;

$| = 1;
use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::OracleObject;

use Net::SNMP;
use Net::Ping;
use Data::Dumper;
use Socket;

use lib "/local/netdb/libs";
use NetMaint::DB;
use Local::AuthSrv;
use Local::SetUID;
use Local::SimpleRPC;

&SetUID("netdb");

print "Opening db...\n";
my $db = new NetMaint::DB;
print "Done.\n";

# Calculate appropriate tftp server address
my $tftphostname = "netstat-netmgmt.srv.mst.edu";
my $packed       = gethostbyname($tftphostname)
    or die "Couldn't resolve address for $tftphostname: $!\n";
my $tftpsrv = inet_ntoa($packed);

# First get the list of ones that we know the subnet/vlan for
print "Retrieving mac block list...\n";
my $qry = "select distinct ether,vlan from mac_block";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);

my %block;
my %dont_remove;
while ( my ( $ether, $vlan ) = $db->SQL_FetchRow($cid) ) {
    next if ( $ether eq "000000000000" || $ether eq "FFFFFFFFFFFF" );
    if ( $vlan ne "" ) {
        $block{$ether}->{$vlan} = 1;
    }
    $dont_remove{$ether} = 1;
}
$db->SQL_CloseQuery($cid);
print "Done.\n";

# Now build up the list of switches
my $qry   = "select distinct host from admin_host_options where config='# DOES_MACBLOCK'";
my $cid   = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
my @hosts = ();
while ( my ($host) = $db->SQL_FetchRow($cid) ) {
    push( @hosts, $host );
}
$db->SQL_CloseQuery($cid);

#
# Host
#
my $p = new Net::Ping;

my $handled_count;
my $skipped_count;
my $fallback_count;

my %handled_oids;
my %skipped_oids;
my %fallback_oids;

foreach my $host (@hosts) {
    if ( $ARGV[0] ne "" ) {
        next if ( $host ne $ARGV[0] );
    }

    print "\n";
    print "Checking Device($host):\n";

    if ( !$p->ping( $host, 2 ) ) {
        print "Device ($host) does not respond to ping. Skipping.\n";
        next;
    }

    my $rw = &AuthSrv_Fetch( user => "rw", instance => "snmp" );

    my ( $session, $error ) = Net::SNMP->session(
        -hostname  => $host,
        -community => $rw,
        -version   => 1,
        -timeout   => 5
    );

    if ($error) {
        warn $error;
        next;
    }

    my $result = $session->get_request( -varbindlist => [ '.1.3.6.1.2.1.1.2.0', '.1.3.6.1.2.1.1.1.0' ], );

    my $oid  = "";
    my $desc = "";
    if ($result) {
        $oid  = $result->{".1.3.6.1.2.1.1.2.0"};
        $desc = $result->{".1.3.6.1.2.1.1.1.0"};
    }
    if ( $session->error() ) {
        print "Error Retrieving Switch OID: ", $session->error(), "\n";
    }
    print "$host: $oid\n";
    print "$host: $desc\n";

    my %handlers = (
        ".1.3.6.1.4.1.9.1.507" => \&process_host_ciscowireless,
        ".1.3.6.1.4.1.9.1.552" => \&process_host_ciscowireless,
        ".1.3.6.1.4.1.9.1.525" => \&process_host_ciscowireless,
        ".1.3.6.1.4.1.9.1.618" => \&process_host_ciscowireless,
    );

    my %uplink = ();

    my $handler = $handlers{$oid};
    my $uplink  = $uplink{$host};

    if ($handler) {
        print "Processing Host Updates($host):\n";
        &$handler( $host, uplink => $uplink );

        push( @{ $handled_oids{$oid} }, $host );
        $handled_count++;
    }
    elsif ( index( $oid, ".1.3.6.1.4.1.9.1" ) == 0 ) {
        $handler = \&process_host_ciscoios12;

        print "Processing Host Updates($host) via Fallback Rule:\n";
        &$handler( $host, uplink => $uplink );

        push( @{ $fallback_oids{$oid} }, $host );
        $fallback_count++;
    }
    else {
        print "Skipping Host Processing($host) - No Defined Handler.\n";
        push( @{ $skipped_oids{$oid} }, $host );
        $skipped_count++;
    }
}

print "\n";
print "Devices Processed - Handler Defined:\n";
print "------------------------------------\n";
foreach my $oid ( sort( keys(%handled_oids) ) ) {
    print $oid, ": ";
    my @hosts = @{ $handled_oids{$oid} };
    print scalar(@hosts), "\n";
    foreach my $host ( sort(@hosts) ) {
        print "\t$host\n";
    }
}

print "\n\n";

print "\n";
print "Devices Processed - Handler Fallback:\n";
print "------------------------------------\n";
foreach my $oid ( sort( keys(%fallback_oids) ) ) {
    print $oid, ": ";
    my @hosts = @{ $fallback_oids{$oid} };
    print scalar(@hosts), "\n";
    foreach my $host ( sort(@hosts) ) {
        print "\t$host\n";
    }
}

print "\n\n";

print "Devices Skipped - No Handler Defined:\n";
print "-------------------------------------\n";
foreach my $oid ( sort( keys(%skipped_oids) ) ) {
    print $oid, ": ";
    my @hosts = @{ $skipped_oids{$oid} };
    print scalar(@hosts), "\n";
    foreach my $host ( sort(@hosts) ) {
        print "\t$host\n";
    }
}

# Begin-Doc
# Name: get_switch_vlans
# Description: get a list of vlans from db cache that are known on a switch
# End-Doc
sub get_switch_vlans {
    my $addr = shift;

    my $qry   = "select distinct vlan from switch_vlans where switch=? and vlan > 0";
    my $cid   = $db->SQL_OpenQuery( $qry, $addr ) || $db->SQL_Error($qry);
    my %vlans = ();
    while ( my ($vlan) = $db->SQL_FetchRow($cid) ) {

        #print "Found vlan $vlan on $addr.\n";
        $vlans{$vlan} = 1;
    }
    $db->SQL_CloseQuery($cid);

    return %vlans;
}

# Begin-Doc
# Name: process_host_ciscoios12
# Description: process mac block entries for a cisco new style device
# End-Doc
sub process_host_ciscoios12 {
    my $addr = shift;
    my %opts = @_;

    my $conf       = &read_conf($addr);
    my %switch_has = ();
    while ( $conf =~ /mac[-\s]address-table static ([0-9a-fA-F\.]+) vlan (\d+) drop/smgo ) {
        my $eth  = uc $1;
        my $vlan = int($2);

        $eth =~ tr/A-F0-9//cd;

        print "Found $eth / $vlan in block list on $addr\n";
        $switch_has{$eth}->{$vlan} = 1;
    }

    #
    # Get the list of vlans from the switch
    #
    my %vlans = &get_switch_vlans($addr);

    my $fname = "newconf-macblock-$addr";

    my $tmpfile = "/local/netdb/tftp/$fname";
    unlink($tmpfile);
    open( my $tmph, ">$tmpfile" );

    my $updates = 0;

    # First figure out what we should add:
    foreach my $mac ( keys(%block) ) {
        my $fmac = make_cisco_mac($mac);

        foreach my $vlan ( keys( %{ $block{$mac} } ) ) {
            if ( !$switch_has{$mac}->{$vlan} && $vlans{$vlan} ) {
                $updates++;

                print "mac-address-table static $fmac vlan $vlan drop\n";
                print $tmph "mac-address-table static $fmac vlan $vlan drop\n";

                print "mac address-table static $fmac vlan $vlan drop\n";
                print $tmph "mac address-table static $fmac vlan $vlan drop\n";
            }
        }
    }

    # Now remove any that are on the switch that shouldn't be
    foreach my $mac ( keys(%switch_has) ) {
        my $fmac = make_cisco_mac($mac);

        foreach my $vlan ( keys( %{ $switch_has{$mac} } ) ) {
            if ( !$block{$mac}->{$vlan} ) {
                if ( $dont_remove{$mac} ) {
                    print "# skipping removal of $mac from $vlan\n";
                }
                else {
                    $updates++;

                    print "no mac-address-table static $fmac vlan $vlan\n";
                    print $tmph "no mac-address-table static $fmac vlan $vlan\n";

                    print "no mac address-table static $fmac vlan $vlan\n";
                    print $tmph "no mac address-table static $fmac vlan $vlan\n";
                }
            }
        }
    }
    print $tmph "!\n";
    print $tmph "end\n";
    close($tmph);

    if ($updates) {
        print "switch update completed.\n";
        &write_conf( $addr, $tmpfile );
    }
}

# Begin-Doc
# Name: process_host_ciscowireless
# Description: process mac block entries for a cisco wireless type device
# End-Doc
sub process_host_ciscowireless {
    my $addr = shift;

    my $conf       = &read_conf($addr);
    my %switch_has = ();
    while ( $conf =~ m#bridge (\d+) address ([0-9a-fA-F\.]+) discard#smigo ) {
        my $eth  = uc $2;
        my $vlan = int($1);

        $eth =~ tr/A-F0-9//cd;

        print "Found $eth / $vlan in block list on $addr\n";
        $switch_has{$eth}->{$vlan} = 1;
    }

    #
    # Get the list of vlans from the switch
    #
    my %vlans = &get_switch_vlans($addr);

    my $fname = "newconf-macblock-$addr";

    my $tmpfile = "/local/netdb/tftp/$fname";
    unlink($tmpfile);
    open( my $tmph, ">$tmpfile" );

    my $updates = 0;

    # First figure out what we should add:
    foreach my $mac ( keys(%block) ) {
        my $fmac = make_cisco_mac($mac);

        foreach my $vlan ( keys( %{ $block{$mac} } ) ) {
            if ( !$switch_has{$mac}->{$vlan} && $vlans{$vlan} ) {
                $updates++;

                print "bridge $vlan address $fmac discard\n";
                print $tmph "bridge $vlan address $fmac discard\n\n";
            }
        }
    }

    # Now remove any that are on the switch that shouldn't be
    foreach my $mac ( keys(%switch_has) ) {
        my $fmac = make_cisco_mac($mac);

        foreach my $vlan ( keys( %{ $switch_has{$mac} } ) ) {
            if ( !$block{$mac}->{$vlan} ) {
                if ( $dont_remove{$mac} ) {
                    print "# skipping removal of $mac from $vlan\n";
                }
                else {
                    $updates++;

                    print "no bridge $vlan address $fmac\n";
                    print $tmph "no bridge $vlan address $fmac\n";
                }
            }
        }
    }
    print $tmph "!\n";
    print $tmph "end\n";
    close($tmph);

    if ($updates) {
        print "switch update completed.\n";
        &write_conf( $addr, $tmpfile );
    }
}

# Begin-Doc
# Name: make_cisco_mac
# Description: format a mac address for input on a cisco device
# End-Doc
sub make_cisco_mac {
    my $mac = shift;
    $mac =~ s/(....)(....)(....)/$1.$2.$3/o;
    return $mac;
}

# Begin-Doc
# Name: write_conf
# Description: write config to a cisco device
# End-Doc
sub write_conf {
    my $addr = shift;
    my $file = shift;
    my $fname;

    if ( $file !~ m|^/local/netdb/tftp/|o ) {
        print "invalid file path for $addr ($file)\n";
        return;
    }

    $fname = $file;
    $fname =~ s|^/local/netdb/tftp/||gio;

    my $tftpsrv      = $tftpsrv;
    my $mib_read     = ".1.3.6.1.4.1.9.2.1.50";
    my $mib_writemem = ".1.3.6.1.4.1.9.2.1.54.0";

    my $rw = &AuthSrv_Fetch( user => "rw", instance => "snmp" );

    my ( $session, $error ) = Net::SNMP->session(
        -hostname  => $addr,
        -community => $rw,
        -version   => 1,
        -timeout   => 60
    );

    if ($error) {
        warn $error;
        return;
    }

    print "Sending commands to merge new config:\n";
    my $result = $session->set_request( -varbindlist => [ "$mib_read.$tftpsrv", OCTET_STRING, "/netdb/$fname" ] );

    if ( !defined($result) ) {
        print $session->error();
        return;
    }
    print "Done.\n";

    print "Sending commands to switch to write memory:\n";
    my $result = $session->set_request( -varbindlist => [ "$mib_writemem", INTEGER, 1 ] );

    if ( !defined($result) ) {
        print $session->error();
        return;
    }
    print "Done.\n";

    &trigger_backup($addr);
}

# Begin-Doc
# Name: read_conf
# Description: read config from a cisco device
# End-Doc
sub read_conf {
    my $addr = shift;

    my $tftpsrv      = $tftpsrv;
    my $mib_writenet = ".1.3.6.1.4.1.9.2.1.55";

    my $rw = &AuthSrv_Fetch( user => "rw", instance => "snmp" );

    my ( $session, $error ) = Net::SNMP->session(
        -hostname  => $addr,
        -community => $rw,
        -version   => 1,
        -timeout   => 60
    );

    die $error if $error;

    open( my $tmph, ">/local/netdb/tftp/conf-$addr" );
    print $tmph "!";
    close($tmph);
    chmod 0666, "/local/netdb/tftp/conf-$addr";

    print "Retrieving config from $addr:\n";
    my $result
        = $session->set_request( -varbindlist => [ "$mib_writenet.$tftpsrv", OCTET_STRING, "/netdb/conf-$addr" ] );

    if ( !defined($result) ) {
        print $session->error();
    }

    chmod 0600, "/local/netdb/tftp/conf-$addr";

    open( my $tmph, "/local/netdb/tftp/conf-$addr" );
    my $res = join( "", <$tmph> );
    close($tmph);

    print "Done.\n";

    return $res;
}

# Begin-Doc
# Name: trigger_backup
# Description: trigger a device backup
# End-Doc
sub trigger_backup {
    my $device = shift;

    my $rpc = new Local::SimpleRPC::Client(
        base_url => "https://netstat.srv.mst.edu/cgi-bin/cgiwrap/cfgbkup/rpc",
        retries  => 2
    );

    print "Triggering backup on $device.\n";
    my $info;
    eval { $info = $rpc->TriggerBackup( device => $device ); };
}

