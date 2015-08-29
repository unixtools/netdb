#!/usr/bin/perl

# Begin-Doc
# Name: ignored-dhcp.pl
# Type: script
# Description: Report on dhcp ignored requests
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
my $util = new NetMaint::Util;

$log->Log();

$html->PageHeader( title => "Ignored DHCP Requests" );

if ( $mode eq "" ) {
    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "mode", "report" );
    print "Ethers ignored in Past: ";
    &HTMLInputText( "days", 10, 1 );
    print " days.<br/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $db   = new NetMaint::DB;
    my $days = int( $rqpairs{days} );

    $html->StartMailWrapper("Ethers Ignored in Past $days Days");

    $html->StartBlockTable("Ethers Ignored in Past $days Days");
    $html->StartInnerTable( "Ethernet Address", "Request Count" );

    my $qry
        = "select ether, count(*) from dhcp_acklog "
        . "where tstamp > date_sub(now(),interval ? day) and type='IGNORE' "
        . "group by ether order by ether";
    my $cid = $db->SQL_OpenQuery( $qry, $days ) || $html->ErrorExitSQL( "list hosts", $db );

    while ( my ( $ether, $cnt ) = $db->SQL_FetchRow($cid) ) {
        $html->StartInnerRow();
        print "<td><tt>", $html->SearchLink_Ether( $util->FormatEther($ether) ), "</td>\n";
        print "<td><tt>$cnt</td>\n";
        $html->EndInnerRow();
    }
    $db->SQL_CloseQuery($cid);

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

