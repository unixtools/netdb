#!/usr/bin/perl

# Begin-Doc
# Name: menu.pl
# Type: script
# Description: netdb main menu
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::PrivSys;
use lib "/local/netdb/libs";

use NetMaint::DB;
require NetMaint::HTML;
use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Tools Menu" );

my $db = new NetMaint::DB;

$html->PageHeader();

chdir("/local/netmap") || die;

my %all_ip = ();

my $debug = 0;
my $line;
my %ip_to_sort;

my @nets = qw(10.155.0 10.155.2 10.155.100 10.71.50);
my $netpat = join( "|", map { quotemeta $_ } @nets );

#
# Load fnfr.com DNS
#
my %ip_to_dns = ();
$debug && print "Scanning fnfr.com DNS\n";
open( my $in, "/usr/bin/dig axfr fnfr.com \@localhost |" );
while ( defined( $line = <$in> ) ) {
    chomp($line);
    $line = lc $line;
    my @tmp = split( ' ', $line );
    my $hn = $tmp[0];
    $hn =~ s/\.$//g;

    if ( $line =~ /\s+((${netpat}).\d+)$/o ) {
        $ip_to_dns{$1}->{$hn} = 1;
    }
}
close($in);

$debug && print "Scanning spirenteng.com DNS\n";
open( my $in, "dig axfr spirenteng.com \@localhost|" );
while ( defined( $line = <$in> ) ) {
    chomp($line);
    $line = lc $line;
    my @tmp = split( ' ', $line );
    my $hn = $tmp[0];
    $hn =~ s/\.$//g;

    if ( $line =~ /\s+((${netpat}).\d+)$/o ) {
        $ip_to_dns{$1}->{$hn} = 1;
    }
}
close($in);

#
# Load reverse DNS
#
my %ip_to_resv = ();

foreach my $net (@nets) {
    my $rnet = join( ".", reverse( split( /\./, $net ) ) );
    $debug && print "Scanning $net DNS\n";
    open( my $in, "dig axfr ${rnet}.in-addr.arpa \@localhost|" );
    while ( defined( $line = <$in> ) ) {
        chomp($line);
        $line = lc $line;
        my @tmp  = split( ' ', $line );
        my @rtmp = reverse(@tmp);
        my $arpa = $tmp[0];
        my $hn   = $rtmp[0];
        $hn =~ s/\.$//g;

        if ( $arpa =~ /^(\d+).${rnet}.in-addr.arpa/ ) {
            my $ip = "${net}.$1";
            $ip_to_resv{$ip}->{$hn} = 1;
        }
    }
    close($in);
}

#
# Load ping status
#
#fping -c 3 -q -g 10.155.2.0/24
# 10.155.2.206 : xmt/rcv/%loss = 3/3/0%, min/avg/max = 0.58/3.16/6.08

my %ip_to_ping = ();

my $qry = "select distinct ip from last_ping_ip where unix_timestamp(now())-unix_timestamp(tstamp) < 120";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
while ( my ($ip) = $db->SQL_FetchRow($cid) )
{
    $ip_to_ping{$ip} = "YES";
}
$db->SQL_CloseQuery($cid);

my %ip_to_alloc;
my $qry = "select ip,host from ip_alloc where host is not null";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
while ( my ($ip,$host) = $db->SQL_FetchRow($cid) )
{
    if ( $host )
    {
        $ip_to_alloc{$ip} = $host;
    }
}
$db->SQL_CloseQuery($cid);

#
#
#
my %ip_to_os    = ();
my %ip_to_ports = ();

foreach my $net (@nets) {
    $debug && print "Loading NMAP scan of ${net}\n";
    open( my $in, "data/nmap-${net}.out" );
    while ( defined( my $line = <$in> ) ) {
        my $host;
        if ( $line =~ /Host: (${net}.\d+)/ ) {
            $host = $1;
        }

        if ( $line =~ /Host: (${net}.\d+).*OS:\s+(.*?)\t/ ) {
            $host = $1;
            $ip_to_os{$host} = $2;
        }

        if ( $line =~ /Ports: (.*)/ ) {
            my @services = ();
            my @match = split( /,/, $1 );
            foreach my $match (@match) {
                my @tmp = split( '/', $match );
                if ( $tmp[1] eq "open" ) {
                    push( @services, $tmp[4] );
                }
            }
            $ip_to_ports{$host} = join( ", ", @services );

        }

    }
    close($in);
}

#
# Generate report
#
$debug && print "Generating sort table...\n";
foreach my $i ( 0 .. 255 ) {
    my $di = sprintf( "%.3d", $i );

    foreach my $net (@nets) {
        my $ip = $net . "." . $i;

        my $sip = join( ".", map { sprintf "%.3d", $_ } split( /\./, $ip ) );
        $ip_to_sort{$ip} = $sip;
    }
}

$debug && print "Generating HTML...\n";

$html->StartBlockTable("DNS/IP Info for Labs", 800);
$html->StartInnerTable();

my $lastskip = 0;
my $prefix   = "";
foreach my $ip ( sort { $ip_to_sort{$a} cmp $ip_to_sort{$b} } keys(%ip_to_sort) ) {

    my $newprefix = $ip;
    $newprefix =~ s/\.\d+$//g;

    if ( $newprefix ne $prefix ) {
        $prefix = $newprefix;
        $html->StartInnerHeaderRow();
        print "<td align=center colspan=4><b>Network Prefix ($prefix)</td>\n";
        $html->EndInnerHeaderRow();

        $html->StartInnerHeaderRow();
        print
            "<td><b>IP</td><td><b>DNS / Alloc<br>(.spirenteng.com)</td><td><b>Ping</td>";
        print "<td width=600><b>OS and Services</td>\n";
        $html->EndInnerHeaderRow();
    }

    my $editprefix = "https://netmgr.spirenteng.com/auth-cgi-bin/cgiwrap/netdb/edit-host.pl?mode=view&host=";

    my %poss_names = ();

    my $dns  = "";
    foreach my $host ( sort( keys( %{ $ip_to_dns{$ip} } ) ) ) {
        next if ( $host eq "" );
        $poss_names{$host} = 1;
    }

    my $resv = "";
    my $ncount = 0;
    foreach my $host ( sort( keys( %{ $ip_to_resv{$ip} } ) ) ) {
        next if ( $host eq "" );
        $poss_names{$host} = 1;
        $ncount++;
    }

    my $alloc = $ip_to_alloc{$ip};
    if ( $alloc )
    {
        $poss_names{$alloc} = 1;
        $ncount++;
    }

    if ( $ncount == 0 && $ip_to_ping{$ip} eq "" && $ip_to_os{$ip} eq "" && $ip_to_ports{$ip} eq "" ) {
        if ($lastskip) {
            next;
        }
        else {
            $html->StartInnerHeaderRow();
            print "<td colspan=5 align=center>... skipped ...</td>\n";
            $html->EndInnerHeaderRow();
            $lastskip = 1;
            next;
        }
    }
    $lastskip = 0;

    $html->StartInnerRow();
    print "<td>$ip</td>\n";

    my @editlinks = ();
    foreach my $name ( sort(keys(%poss_names)) )
    {
        my $sname = $name;
        $sname =~ s/.spirenteng.com//go;
        push(@editlinks, "<a href=\"${editprefix}$name\">$sname</a>");
    }
    print "<td>", join("<br>\n", @editlinks), "</td>\n";

    print "<td align=center>\n";
    print $ip_to_ping{$ip};
    print "</td>\n";

    print "<td width=400><font size=-1>\n";
    print $ip_to_os{$ip};
    if ( $ip_to_ports{$ip} ne "" ) {
        if ( $ip_to_os{$ip} ) {
            print "<br>\n";
        }
        print "Ports(" . $ip_to_ports{$ip} . ")";
    }
    print "</td>\n";

    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();
