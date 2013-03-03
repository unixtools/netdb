#!/usr/bin/perl

# Begin-Doc
# Name: dhcp-high-counts.pl
# Type: script
# Description: Report on excessive dhcp request counts
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

$html->PageHeader( title => "DHCP Excessive Request Report" );

if ( $mode eq "" ) {
    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "mode", "report" );
    print "Number of Requests: ";
    &HTMLInputText( "requests", 10, 150 );
    print " requests.<br/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $db       = new NetMaint::DB;
    my $requests = int( $rqpairs{requests} );

    $html->StartMailWrapper("DHCP Excessive Requests (Threshold $requests)");

    $html->StartBlockTable("DHCP Excessive Requests (Threshold $requests)");

    $html->StartInnerTable( "Type", "Ether", "IP", "Count", "7-Day Count", "Timestamp" );

    my $qry
        = "select type, ether, ip, count(*) cnt, max(tstamp) from dhcp_acklog "
        . "where tstamp > date_sub(now(),interval 1 day) "
        . "group by type, ether, ip having count(*) > $requests "
        . "order by cnt desc, ether";

    my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

    my $qry2
        = "select count(*) from dhcp_acklog where type=? and ether=? and ip=? and tstamp > date_sub(now(),interval 7 day)";
    my $cid2 = $db->SQL_OpenBoundQuery($qry2) || $db->SQL_Error($qry2) && die;

    my $qry3
        = "select count(*) from dhcp_acklog where type=? and ether=? and ip is null and tstamp > date_sub(now(),interval 7 day)";
    my $cid3 = $db->SQL_OpenBoundQuery($qry3) || $db->SQL_Error($qry3) && die;

    while ( my ( $type, $ether, $ip, $cnt, $tstamp ) = $db->SQL_FetchRow($cid) ) {
        $html->StartInnerRow();

        print "<td>$type\n";
        print "<td>", $html->SearchLink_Ether($ether), "\n";
        print "<td>", $html->SearchLink_IP($ip),       "\n";
        print "<td>$cnt\n";

        $db->SQL_ExecQuery( $cid2, $type, $ether, $ip );
        my ($longcnt) = $db->SQL_FetchRow($cid2);

        if ( $longcnt == 0 ) {
            $db->SQL_ExecQuery( $cid3, $type, $ether );
            ($longcnt) = $db->SQL_FetchRow($cid3);
        }

        print "<td>$longcnt\n";

        print "<td>$tstamp\n";

        $html->EndInnerRow();

    }
    $db->SQL_CloseQuery($cid);

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

