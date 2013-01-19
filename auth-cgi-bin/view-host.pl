#!/usr/bin/perl

# Begin-Doc
# Name: view-host.pl
# Type: script
# Description: view details for a host
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
    $html->ErrorExit( "Host (" . $html->Encode($host) . ") not found." );
}

# if we have permission to mess with this host
if ( $access->CheckHostEditAccess( host => $host ) ) {
    print "<p/>\n";
    print "<a href=\"edit-host.pl?mode=view&host=$host\">";
    print "Edit host registration for $host</a>\n";
}

if ( !$access->CheckHostViewAccess( host => $host ) ) {
    print "<p/>\n";
    print "<a target=_history href=\"view-host-history.pl?mode=view&host=$host\">";
    print "View history for $host</a>\n";
}

$html->StartMailWrapper("Host Details for $host");

print "<p/>\n";
$html->Display_HostInfo($info);

print "<p/>\n";
$html->Display_Person( title => "Owner Details", userid => $info->{owner} );

my @addresses = $net->GetHostAddresses($host);

print "<p/>\n";
$html->StartBlockTable( "Registered IP Addresses", 500 );
$html->StartInnerTable( "IP", "Subnet", "Mask", "Gateway" );
my $sninfo = $net->GetSubnets();
foreach my $ip (@addresses) {
    my $gw;
    my $mask;
    my $sn;
    my %ipinfo = $net->GetAddressDetail($ip);
    $sn = $ipinfo{subnet};
    if ($sn) {
        $gw   = $sninfo->{$sn}->{gateway};
        $mask = $sninfo->{$sn}->{mask};
    }

    $html->StartInnerRow();
    print "<td align=center>", $ip, "</td>\n";
    print "<td align=center>", $sn   || "&nbsp;", "</td>\n";
    print "<td align=center>", $mask || "&nbsp;", "</td>\n";
    print "<td align=center>", $gw   || "&nbsp;", "</td>\n";
    print "</td>\n";
    $html->EndInnerRow();
}
$html->EndInnerTable();
$html->EndBlockTable();

my @ethers = $dhcp->GetEthers($host);

print "<p/>\n";
$html->StartBlockTable( "Registered Ethernet Addresses", 500 );
$html->StartInnerTable();
foreach my $ether (@ethers) {
    $html->StartInnerRow();
    print "<td align=center>", $util->FormatEther($ether), "</td>\n";
    $html->EndInnerRow();
}
$html->EndInnerTable();
$html->EndBlockTable();

foreach my $ether (@ethers) {
    my $dhcphist = $dhcp->GetDHCPHistory( ether => $ether );
    print "\n<p/>\n";
    $html->Display_DHCP_History(
        title    => "Condensed DHCP History - " . $util->FormatEther($ether),
        entries  => $dhcphist,
        condense => 1
    );
}

my @options = $dhcp->GetHostOptions($host);
if ( $#options >= 0 ) {
    print "\n<p/>\n";
    $html->Display_DHCP_Host_Options(
        title   => "DHCP Host Options",
        options => \@options
    );
}

my @options = $dhcp->GetAdminOptions($host);
if ( $#options >= 0 ) {
    print "\n<p/>\n";
    $html->Display_Admin_Host_Options(
        title   => "Admin Host Options",
        options => \@options
    );
}

my @mx_recs = $dns->Get_MX_Records($host);
if ( $#mx_recs >= 0 ) {
    print "\n<p/>\n";
    $html->Display_MX_Records(
        title   => "Mail Exchanger Records - $host",
        records => \@mx_recs
    );
}

my @cname_recs = $dns->Get_CNAME_Records($host);
if ( $#cname_recs >= 0 ) {
    print "\n<p/>\n";
    $html->Display_CNAME_Records(
        title   => "Canonical Name Records - $host",
        records => \@cname_recs
    );
}

my @cname_recs = $dns->Get_CNAME_Records_Target($host);
if ( $#cname_recs >= 0 ) {
    print "\n<p/>\n";
    $html->Display_CNAME_Records(
        title   => "Canonical Name Records for Target - $host",
        records => \@cname_recs
    );
}

my @a_recs = $dns->Get_A_Records($host);
if ( $#a_recs >= 0 ) {
    print "\n<p/>\n";
    $html->Display_A_Records(
        title   => "Address Records - $host",
        records => \@a_recs
    );
}

foreach my $rec (@a_recs) {
    my $ip = $rec->{address};
    my $dhcphist = $dhcp->GetDHCPHistory( ip => $ip );
    print "\n<p/>\n";
    $html->Display_DHCP_History(
        title    => "Condensed DHCP History - $ip",
        entries  => $dhcphist,
        condense => 1
    );
}

$html->EndMailWrapper();
$html->PageFooter();

