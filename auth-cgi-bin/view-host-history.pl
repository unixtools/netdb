#!/usr/bin/perl

# Begin-Doc
# Name: view-host-history.pl
# Type: script
# Description: view history of changes for a host
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Logging;
require NetMaint::Network;

use Local::PrivSys;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "View Host" );

$html->PageHeader();

my $hosts  = new NetMaint::Hosts;
my $dhcp   = new NetMaint::DHCP;
my $util   = new NetMaint::Util;
my $dns    = new NetMaint::DNS;
my $log    = new NetMaint::Logging;
my $access = new NetMaint::Access;
my $net    = new NetMaint::Network;

my $host = $rqpairs{host};

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs('public') );

$log->Log();

if ( !$host ) {
    $html->ErrorExit("No host specified.");
}

if ( !$access->CheckHostViewAccess( host => $host ) ) {
    $html->ErrorExit( "Permission denied to view host (<tt>", $html->Encode($host), "</tt>)." );
}

my $info = $hosts->GetHostInfo($host);
if ( !$info ) {
    print "Host (", $html->Encode($host), ") not currently registered, displaying old history.\n";
    print "<p/>\n";
}

$html->StartMailWrapper("History for $host");

if ($info) {
    print "<p/>\n";
    $html->Display_HostInfo($info);
}

print "<p/>\n";
$html->StartBlockTable( "History for host $host", 750 );
$html->StartInnerTable( "Date", "App", "Action", "Message" );

my $db = new NetMaint::DB;
my $qry
    = "select tstamp,app,action,userid,ether,address,status,msg " . "from netdb.log where host=? order by tstamp desc";
my $cid = $db->SQL_OpenQuery( $qry, $host )
    || $html->ErrorExitSQL( "list hosts", $db );

while ( my ( $tstamp, $app, $action, $userid, $ether, $address, $status, $msg ) = $db->SQL_FetchRow($cid) ) {
    next if ( $action eq "" );
    next if ( $action eq "view" );
    next if ( $action eq "search" );
    next if ( $action eq "triggered dhcp update" );

    $html->StartInnerRow();
    print "<td>$tstamp</td>\n";
    print "<td>$app</td>\n";
    print "<td>$userid: $action";
    if ($status) {
        print " ($status)";
    }
    print "</td>\n";
    print "<td>$msg</td>\n";

    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

$html->EndMailWrapper();
$html->PageFooter();

