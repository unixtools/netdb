#!/usr/bin/perl

# Begin-Doc
# Name: hosts-by-domain.pl
# Type: script
# Description: Report on count of hosts by subdomain
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::DB;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Host Registrations by Domain" );

print "This report indicates the number of hosts registered in each subdomain\n";
print "available in the registration system.\n";
print "<p/>\n";

my $db = new NetMaint::DB;

my $qry = "select domain,count(*) from hosts group by domain order by domain";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

my $total_count   = 0;
my $total_domains = 0;

$html->StartMailWrapper("Host Registrations by Domain");
$html->StartBlockTable("Host Registrations by Domain");
$html->StartInnerTable( "Count", "Domain" );

while ( my ( $domain, $count ) = $db->SQL_FetchRow($cid) ) {
    $html->StartInnerRow();
    print "<td align=right>$count</td><td>$domain</td>\n";
    $html->EndInnerRow();

    $total_count += $count;
    $total_domains++;
}

$html->StartInnerRow();
print "<td colspan=3>";
print "<b>Total Domains:</b> $total_domains\n";
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td colspan=3>";
print "<b>Total Hosts Registered:</b> $total_count\n";
print "</td>\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();
