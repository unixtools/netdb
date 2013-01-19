#!/usr/bin/perl

# Begin-Doc
# Name: improper-ip-use.pl
# Type: script
# Description: Report on improper ip address usage
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
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Improper IP Usage Report" );

my $db       = new NetMaint::DB;
my $requests = int( $rqpairs{requests} );

$html->StartMailWrapper("Improper IP Usage Report");

$html->StartBlockTable("Improper IP Usage Report");

$html->StartInnerTable( "IP", "Ether", "IP Allocated to Host", "Ether Registered To Host" );

my $qry = "select distinct a.ip,
       a.ether,
       b.host,
       d.name
  from arpscan a
       left outer join ip_alloc b on a.ip = b.ip
       left outer join dhcp_curleases c on (a.ip = c.ip and a.ether=c.ether)
       left outer join ethers d on a.ether = d.ether 
 where a.latest = 1
   and a.ip like '131.151.%'
   and ( c.ip is null or c.ether is null )
   and ( b.host is null or b.host != d.name ) order by d.name,a.ip";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ( $ip, $ether, $allochost, $etherhost ) = $db->SQL_FetchRow($cid) ) {
    next
        if ( $allochost =~ /^hsrp-.*network/o
        && $etherhost =~ /^hsrp-.*network/o );
    next
        if ( $allochost =~ /^nccs-.*network/o
        && $etherhost =~ /^nccs-.*network/o );
    next
        if ( $allochost =~ /^ncpk-.*network/o
        && $etherhost =~ /^ncpk-.*network/o );
    next
        if ( $allochost =~ /^nchc-.*network/o
        && $etherhost =~ /^nchc-.*network/o );

    next if ( $allochost =~ /^vpn-/ && $etherhost =~ /^sysvpn/o );
    next if ( $ip =~ /131\.151\.(0|1|35|248)\./o );

    # ignore broadcast
    next if ( $ether =~ /^ffffffffffff$/io );
    next if ( $ether =~ /^00000fffffff$/io );

    $html->StartInnerRow();

    print "<td>", $html->SearchLink_IP($ip),          "\n";
    print "<td>", $html->SearchLink_Ether($ether),    "\n";
    print "<td>", $html->SearchLink_Host($allochost), "\n";
    print "<td>", $html->SearchLink_Host($etherhost), "\n";

    $html->EndInnerRow();

}
$db->SQL_CloseQuery($cid);

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

