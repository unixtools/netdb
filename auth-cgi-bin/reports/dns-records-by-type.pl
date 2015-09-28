#!/usr/bin/perl

# Begin-Doc
# Name: dns-records-by-type.pl
# Type: script
# Description: Report on dns record counts by type of record
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

$html->PageHeader( title => "DNS Records by Record Type" );

print "This report indicates the number of dns records of each type that ";
print "are in the system.\n";
print "<p/>\n";

my $db = new NetMaint::DB;

my %dns_tables = (
    "dns_a"     => "Address Records (A)",
    "dns_aaaa"  => "Address Records (AAAA)",
    "dns_mx"    => "Mail Exchanger Records (MX)",
    "dns_cname" => "Canonical Name Records (CNAME)",
    "dns_srv"   => "Service Location Records (SRV)",
    "dns_txt"   => "Textual Information Records (TXT)",
    "dns_ptr"   => "Reverse Lookup Records (PTR)",
    "dns_soa"   => "Start of Authority Records (SOA)",
    "dns_ns"    => "Nameserver Records (NS)",
);

my $total_count = 0;

$html->StartMailWrapper("DNS Record Counts by Type");

$html->StartBlockTable( "DNS Record Counts by Type", 300 );
$html->StartInnerTable( "Type", "Count" );

foreach my $table ( sort( keys(%dns_tables) ) ) {
    my $qry     = "select count(*) from $table";
    my $cid     = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
    my ($count) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    next if ( $count == 0 );

    my $type = $dns_tables{$table};

    $html->StartInnerRow();
    print "<td>$type</td><td align=right>$count</td>\n";
    $html->EndInnerRow();

    $total_count += $count;
}

$html->StartInnerRow();
print "<td><b>Total Records:</b></td><td align=right>$total_count</td>\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();

my $total_count = 0;
print "<p/>\n";
$html->StartBlockTable( "Dynamic Record Counts by Type", 300 );
$html->StartInnerTable( "Type", "Count" );

foreach my $table ( sort( keys(%dns_tables) ) ) {
    my $qry     = "select count(*) from $table where dynamic=1";
    my $cid     = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
    my ($count) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    my $type = $dns_tables{$table};

    next if ( $count == 0 );

    $html->StartInnerRow();
    print "<td>$type</td><td align=right>$count</td>\n";
    $html->EndInnerRow();

    $total_count += $count;
}

$html->StartInnerRow();
print "<td><b>Total Dynamic Records:</b></td><td align=right>$total_count</td>\n";
$html->EndInnerRow();
$html->EndInnerTable();
$html->EndBlockTable();

my $total_count = 0;
print "\n<p/>\n";
$html->StartBlockTable( "Static Record Counts by Type", 300 );
$html->StartInnerTable( "Type", "Count" );

foreach my $table ( sort( keys(%dns_tables) ) ) {
    my $qry     = "select count(*) from $table where (dynamic!=1 or dynamic is null)";
    my $cid     = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
    my ($count) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    my $type = $dns_tables{$table};

    next if ( $count == 0 );

    $html->StartInnerRow();
    print "<td>$type</td><td align=right>$count</td>\n";
    $html->EndInnerRow();

    $total_count += $count;
}

$html->StartInnerRow();
print "<td><b>Total Static Records:</b></td><td align=right>$total_count</td>\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();

$html->EndMailWrapper();

$html->PageFooter();
