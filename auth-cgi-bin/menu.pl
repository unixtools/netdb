#!/usr/bin/perl

# Begin-Doc
# Name: menu.pl
# Type: script
# Description: netdb main menu
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::PrivSys;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Access;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Tools Menu" );
my $access = new NetMaint::Access;

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs("public") );

$html->PageHeader();

print "<p/>\n";

$html->StartBlockTable( "Instructions", 500 );
$html->StartInnerTable();
$html->StartInnerRow();
print "<td>\n";
print "A menu of available applications is listed below. The list\n";
print "of applications will vary according to the access privileges\n";
print "you have been granted.\n";
print "</td>\n";
$html->EndInnerRow();
$html->EndInnerTable();
$html->EndBlockTable();

print "<p/>\n";

$html->StartBlockTable( "Host Registration and Status Tools", 400 );
$html->StartInnerTable();

$html->StartInnerRow();
print "<td><a href=\"edit-host.pl\">Edit or Register Host Details</a> (Expert)</td>\n";
$html->EndInnerRow();
$html->StartInnerRow();
print "<td><a href=\"create-host.pl\">Create New Host</a> (Expert)</td>\n";
$html->EndInnerRow();

if ( $privs{"netdb-admin"} ) {
    $html->StartInnerRow();
    print "<td><a href=\"search-hosts.pl\">Search Hosts</a></td>\n";
    $html->EndInnerRow();
}
$html->StartInnerRow();
print "<td><a href=\"view-my-info.pl\">View Current Connection Info</a></td>\n";
$html->EndInnerRow();
$html->EndInnerTable();
$html->EndBlockTable();

if (   $privs{"netdb-admin"} )
{
    print "<p/>\n";
    $html->StartBlockTable( "Administrative Tools", 400 );
    $html->StartInnerTable();

    if ( $privs{"netdb-admin"} ) {
        $html->StartInnerRow();
        print "<td><a href=\"edit-privs.pl\">Access Control Admin</a></td>\n";
        $html->EndInnerRow();
        $html->StartInnerRow();
        print "<td><a href=\"edit-ip-alloc.pl\">Subnet IP Allocation Editor</a></td>\n";
        $html->EndInnerRow();
        $html->StartInnerRow();
        print "<td><a href=\"edit-vlans.pl\">VLAN Editor</a></td>\n";
        $html->EndInnerRow();
        $html->StartInnerRow();
        print "<td><a href=\"edit-quotas.pl\">Edit Registration Quotas</a></td>\n";
        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();
}

if ( $privs{"netdb-admin"} ) {
    print "<p/>\n";
    $html->StartBlockTable( "System and Host Status Reports", 500 );
    $html->StartInnerTable();

    $html->StartInnerRow();
    print "<td><a href=\"reports/subnet-ip-alloc.pl\">Subnet IP Allocation Report</a></td>\n";
    print "<td><a href=\"reports/history-ip-dhcp.pl\">DHCP History by IP</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/history-ether-dhcp.pl\">DHCP History by Ether</a></td>\n";
    print "<td><a href=\"reports/hosts-by-domain.pl\">Host Count by Domain</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/dns-records-by-type.pl\">DNS Records by Type</a></td>\n";
    print "<td><a href=\"reports/subnet-listing.pl\">Subnet Listing</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/subnet-freeip.pl\">Subnet Free IP List</a></td>\n";
    print "<td><a href=\"reports/subnet-expireip.pl\">Subnet IP Expiration Report</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/systems-seen.pl\">Seen IP/Systems Report</a></td>\n";
    print "<td><a href=\"reports/admin-comments-report.pl\">Admin Comments Report</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/ignored-dhcp.pl\">Ignored DHCP Requests</a></td>\n";
    print "<td><a href=\"reports/dhcp-usage.pl\">DHCP Usage Summary</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/host-expiration.pl\">Host Expiration</a></td>\n";
    print "<td><a href=\"reports/dhcp-high-counts.pl\">Excessive DHCP Requests</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/disabled-hosts.pl\">Disabled Hosts</a></td>\n";
    print "<td><a href=\"reports/admin-options-report.pl\">Admin Options Report</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/quota-report.pl\">Quota Report</a></td>\n";
    print "<td><a href=\"reports/quota-usage-report.pl\">Quota Usage Report</a></td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td><a href=\"reports/host-options-report.pl\">Host Options Report</a></td>\n";
    print "<td><a href=\"reports/subnet-special-addr.pl\">Subnet Special Addr Report</a></td>\n";
    $html->EndInnerRow();
    $html->StartInnerRow();
    print "<td><a href=\"reports/subnet-visualizer.pl\">Subnet Visualizer</a></td>\n";
    print "<td><a href=\"reports/cnames-by-target.pl\">CNames by Target</a></td>\n";
    $html->EndInnerRow();
    $html->StartInnerRow();
    print "<td><a href=\"reports/active-hosts-dump.pl\">Active Hosts by Employee/Dept</a></td>\n";
    print "<td><a href=\"reports/live-dhcp-usage.pl\">Live DHCP Usage</a></td>\n";
    $html->EndInnerRow();

    $html->EndInnerTable();
    $html->EndBlockTable();
}

$html->PageFooter();
