#!/usr/bin/perl

# Begin-Doc
# Name: dhcp-usage.pl
# Type: script
# Description: Report on dhcp usage by subnet
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
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "DHCP Usage Report" );

if ( $mode eq "" ) {
    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "mode", "report" );
    print "DHCP Usage in past: ";
    &HTMLInputText( "days", 10, 2 );
    print " days.<br/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $db   = new NetMaint::DB;
    my $days = int( $rqpairs{days} );

    $html->StartMailWrapper("DHCP Usage in Past $days Days");

    $html->StartBlockTable("DHCP Usage in Past $days Days");
    $html->StartInnerTable( "Dyn Used", "Dyn Allocated", "Subnet", "Description" );

    #
    # First load usage
    #
    my $qry
        = "select a.subnet,count(distinct a.ip) from "
        . "ip_alloc a, dhcp_lastack b where "
        . "a.type = 'dynamic' and "
        . "a.ip = b.ip and b.tstamp > date_sub(now(),interval ? day) "
        . "group by a.subnet";
    my $cid = $db->SQL_OpenQuery( $qry, $days ) || $db->SQL_Error($qry);
    my %usage = ();

    while ( my ( $sn, $cnt ) = $db->SQL_FetchRow($cid) ) {
        $usage{$sn} += $cnt;
    }
    $db->SQL_CloseQuery($cid);

    #
    # Load allocation by type
    #
    my $qry   = "select subnet,count(*) from ip_alloc " . "where type='dynamic' group by subnet";
    my $cid   = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
    my %alloc = ();
    while ( my ( $sn, $cnt ) = $db->SQL_FetchRow($cid) ) {
        $alloc{$sn} += $cnt;
    }
    $db->SQL_CloseQuery($cid);

    # Now make sure every subnet shows up in list:
    my $net    = new NetMaint::Network;
    my $sninfo = $net->GetSubnets();

    my $tally_dyn_used  = 0;
    my $tally_alloc_dyn = 0;
    foreach my $sn ( $net->NetworkSort( keys(%$sninfo) ) ) {
        my $dyn_used  = int( $usage{$sn} );
        my $dyn_alloc = int( $alloc{$sn} );
        next if ( $dyn_alloc == 0 );

        my $color = "black";
        if ( $dyn_used / $dyn_alloc > .90 ) {
            $color = "red";
        }
        elsif ( $dyn_used / $dyn_alloc > .75 ) {
            $color = "orange";
        }

        $tally_dyn_used  += $dyn_used;
        $tally_alloc_dyn += $dyn_alloc;

        my $desc = $sninfo->{$sn}->{description};

        $html->StartInnerRow();
        print "<td><font COLOR=$color>$dyn_used</td>\n";
        print "<td><font COLOR=$color>$dyn_alloc</td>\n";
        print "<td><font COLOR=$color>$sn</td>\n";
        print "<td><font COLOR=$color>$desc</td>\n";
        $html->EndInnerRow();
    }

    $html->StartInnerRow();
    print "<td><b>$tally_dyn_used</td>\n";
    print "<td><b>$tally_alloc_dyn</td>\n";
    print "<td colspan=2><b>Tally of ALL above counts</td>\n";
    $html->EndInnerRow();

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

