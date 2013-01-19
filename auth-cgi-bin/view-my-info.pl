#!/usr/bin/perl

# Begin-Doc
# Name: view-my-info.pl
# Type: script
# Description: view information on current network connection
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::Util;
require NetMaint::Logging;
require NetMaint::Leases;
require NetMaint::DHCP;

use UMR::PrivSys;
use Socket;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "View My Information" );

$html->PageHeader();

my $db     = new NetMaint::DB;
my $leases = new NetMaint::Leases;
my $log    = new NetMaint::Logging;
my $dhcp   = new NetMaint::DHCP;
my $util   = new NetMaint::Util;

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs('public') );

$log->Log();

$html->StartBlockTable( "Current Host Information", 500 );
$html->StartInnerTable();

my $addr = $ENV{"HTTP_X_FORWARDED_FOR"} || $ENV{REMOTE_ADDR};

$html->StartInnerRow();
print "<td>Current Remote IP Address:</td>\n";
print "<td>", $addr, "</td>\n";
$html->EndInnerRow();

my $hn = "";
if ($addr) {
    my $iaddr = inet_aton($addr);
    $hn = gethostbyaddr( $iaddr, AF_INET );
}

$html->StartInnerRow();
print "<td>Current Remote Host Name:</td>\n";
print "<td>", $hn, "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td>Current Remote User Name:</td>\n";
print "<td>", $ENV{REMOTE_USER}, "</td>\n";
$html->EndInnerRow();

my $ether = $leases->GetCurLeaseByIP($addr);

if ($ether) {
    $html->StartInnerRow();
    print "<td>Current Hardware Address:</td>\n";
    print "<td>", $util->FormatEther($ether), "</td>";
    $html->EndInnerRow();

    my $host = $dhcp->SearchByEtherExact($ether);
    if ( !$host ) {
        $host = "not registered";
    }

    $html->StartInnerRow();
    print "<td>Current Registered Host Name:</td>\n";
    print "<td>$host</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print
        "<td colspan=2 align=center><a href=\"/auth-cgi-bin/cgiwrap/netdb/register-desktop.pl?ether=$ether\">Register this machine</a></td>\n";
    $html->EndInnerRow();
}
else {
    $html->StartInnerRow();
    print
        "<td colspan=2 align=center><a href=\"/auth-cgi-bin/cgiwrap/netdb/register-desktop.pl\">Register a machine</a></td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();

