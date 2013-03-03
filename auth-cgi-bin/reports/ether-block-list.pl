#!/usr/bin/perl

# Begin-Doc
# Name: ether-block-list.pl
# Type: script
# Description: Report on ethernet addresses blocked at switches
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

$html->PageHeader( title => "Switch Ether Block Report" );

my $db = new NetMaint::DB;

$html->StartMailWrapper("Switch Ether Block Report");

$html->StartBlockTable("Switch Ether Block Report");

$html->StartInnerTable( "Host", "Ether", "VLAN" );

my $qry = "select a.ether,a.vlan,b.name 
  from mac_block a,
       ethers b
 where a.ether = b.ether
   order by b.name,a.ether,a.vlan";

my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ( $ether, $vlan, $name ) = $db->SQL_FetchRow($cid) ) {
    $html->StartInnerRow();

    print "<td>", $html->SearchLink_Host($name),   "\n";
    print "<td>", $html->SearchLink_Ether($ether), "\n";
    print "<td>", $vlan, "\n";

    $html->EndInnerRow();

}
$db->SQL_CloseQuery($cid);

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

