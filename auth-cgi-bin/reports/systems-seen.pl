#!/usr/bin/perl

# Begin-Doc
# Name: systems-seen.pl
# Type: script
# Description: Report on hosts seen on a subnet
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DB;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("netdb-user");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Systems Seen Report" );

if ( $mode eq "" ) {
    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "mode", "report" );
    print "Systems/IPs Seen in Past: ";
    &HTMLInputText( "days", 10, 7 );
    print " days.<br/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $db   = new NetMaint::DB;
    my $days = int( $rqpairs{days} );

    $html->StartMailWrapper("Systems Seen in Past $days Days");

    $html->StartBlockTable("Systems Seen in Past $days Days");
    $html->StartInnerTable( "IP Count", "Ether Count", "Subnet", "Description" );

    my $tally_eth = 0;
    my $tally_ip  = 0;

    my $qry
        = "select count(distinct arpscan.ether),count(distinct arpscan.ip),ip_alloc.subnet from arpscan,ip_alloc "
        . "where arpscan.tstamp > date_sub(now(),interval 7 day) and "
        . "arpscan.ip = ip_alloc.ip "
        . "group by ip_alloc.subnet";

    my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);

    my %info;
    while ( my ( $ethcnt, $ipcnt, $sn ) = $db->SQL_FetchRow($cid) ) {
        $info{$sn}->{ipcnt}  = $ipcnt;
        $info{$sn}->{ethcnt} = $ethcnt;
        $tally_eth += $ethcnt;
        $tally_ip  += $ipcnt;
    }
    $db->SQL_CloseQuery($cid);

    # Now make sure every subnet shows up in list:
    my $net = new NetMaint::Network;

    my $sninfo = $net->GetSubnets();
    foreach my $sn ( keys %$sninfo ) {
        $info{$sn}->{desc} = $sninfo->{$sn}->{description};
        $info{$sn}->{ipcnt}  += 0;
        $info{$sn}->{ethcnt} += 0;
    }

    my %orig_desc;
    my %seen_desc;
    my %tally_desc_eth;
    my %tally_desc_ip;
    foreach my $sn ( $net->NetworkSort( keys(%info) ) ) {
        my $ipcnt  = $info{$sn}->{ipcnt};
        my $ethcnt = $info{$sn}->{ethcnt};
        my $desc   = $info{$sn}->{desc};

        $html->StartInnerRow();
        print "<td>$ipcnt</td>\n";
        print "<td>$ethcnt</td>\n";
        print "<td>$sn</td>\n";
        print "<td>$desc</td>\n";
        $html->EndInnerRow();

        my $tmpdesc = $desc;
        if ( $desc =~ /-/ || $desc =~ /:/ ) {
            $tmpdesc =~ s/-.*$//gio;
            $tmpdesc =~ s/:.*$//gio;
            $tmpdesc =~ s/\s+$//gio;
            $orig_desc{$tmpdesc} = $desc;
            $seen_desc{$tmpdesc}++;
            $tally_desc_ip{$tmpdesc}  += $ipcnt;
            $tally_desc_eth{$tmpdesc} += $ethcnt;
        }
    }

    foreach my $desc ( sort( keys(%seen_desc) ) ) {
        my $orig = $orig_desc{$desc};
        if ( ( $seen_desc{$desc} >= 4 ) || $orig =~ /^\s*[A-Z]*\s*:/o ) {
            my $tally_ip  = $tally_desc_ip{$desc};
            my $tally_eth = $tally_desc_eth{$desc};

            $html->StartInnerRow();
            print "<td><b>$tally_ip</td>\n";
            print "<td><b>$tally_eth</td>\n";
            print "<td colspan=2><b>Tally of '$desc' counts</td>\n";
            $html->EndInnerRow();
        }
    }

    $html->StartInnerRow();
    print "<td><b>$tally_ip</td>\n";
    print "<td><b>$tally_eth</td>\n";
    print "<td colspan=2><b>Tally of ALL above counts</td>\n";
    $html->EndInnerRow();

    my $qry
        = "select count(distinct arpscan.ether),count(distinct arpscan.ip) "
        . "from arpscan "
        . "where arpscan.tstamp > date_sub(now(),interval 7 day)";

    my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
    my ( $ethcnt, $ipcnt ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    $html->StartInnerRow();
    print "<td><b>$ipcnt</td>\n";
    print "<td><b>$ethcnt</td>\n";
    print "<td colspan=2><b>Total seen on campus</td>\n";
    $html->EndInnerRow();

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

