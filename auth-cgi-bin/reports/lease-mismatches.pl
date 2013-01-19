#!/usr/bin/perl

# Begin-Doc
# Name: lease-mismatches.pl
# Type: script
# Description: Report on hosts with leases not matching actual hw addr in use
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
&PrivSys_RequirePriv("netdb-admin");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "DHCP Lease Mismatch Report" );

my $db       = new NetMaint::DB;
my $requests = int( $rqpairs{requests} );

$html->StartMailWrapper("DHCP Lease Mismatch Report");

$html->StartBlockTable("DHCP Lease Mismatch Report");

$html->StartInnerTable( "IP", "ARP Ether", "Lease Ether", "ARP Host", "Lease Host" );

my $qry = "select a.ip,
       a.ether,
       b.ether,
       c.name,
       d.name
  from arpscan a
       join dhcp_curleases b on (a.ip = b.ip)
       left outer join ethers c on (a.ether = c.ether)
       left outer join ethers d on (b.ether = d.ether)
 where a.latest = 1
   and a.ether != b.ether
   order by c.name,d.name";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ( $ip, $arpether, $leaseether, $arphost, $leasehost ) = $db->SQL_FetchRow($cid) ) {
    next if ( $arpether eq "00000FFFFFFF" );

    $html->StartInnerRow();

    print "<td>", $html->SearchLink_IP($ip),            "\n";
    print "<td>", $html->SearchLink_Ether($arpether),   "\n";
    print "<td>", $html->SearchLink_Ether($leaseether), "\n";
    print "<td>", $html->SearchLink_Host($arphost),     "\n";
    print "<td>", $html->SearchLink_Host($leasehost),   "\n";

    $html->EndInnerRow();

}
$db->SQL_CloseQuery($cid);

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

