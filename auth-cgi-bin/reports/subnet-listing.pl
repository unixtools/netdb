#!/usr/bin/perl

# Begin-Doc
# Name: subnet-listing.pl
# Type: script
# Description: list of subnets
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Logging;

use Local::PrivSys;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->RequirePriv("netmgr-user");

$html->PageHeader( title => "Subnet Listing" );

&HTMLStartForm( &HTMLScriptURL(), "GET" );

print "This report indicates the currently defined subnets on the network.\n";
print "<p/>\n";
print "<a href=\"?\">Show all networks</a> | ";
print "Filter: ";
&HTMLInputText( "filter", 15, $html->Encode( $rqpairs{filter} ) );
print " ";
&HTMLSubmit("Filter");
&HTMLEndForm();
print "<br>\n";
print "<a href=\"?filterexact=SRV\">Show server networks</a> | ";
print "<a href=\"?filterexact=TEST\">Show test networks</a>\n";

my $net = new NetMaint::Network;

my $info  = $net->GetSubnets();
my $vlans = $net->GetVLANs();

my $filter      = $rqpairs{filter};
my $filterexact = $rqpairs{filterexact};

my $which = "All";
if ($filter) {
    $which = $filter;
}
elsif ($filterexact) {
    $which = $filterexact;
}

my $search;
if ($filter) {
    $search .= "filter=$filter&";
}
if ($filterexact) {
    $search .= "filterexact=$filterexact&";
}

$html->StartBlockTable( "Subnets ($which)", 1000 );

$html->StartDTable(
    id             => "subnets",
    columns        => [ "Subnet", "Actions", "VLan", "Template", "Mask", "Gateway", "Description", ],
    filter         => $filter,
    source         => "/auth-cgi-bin/cgiwrap/netdb/reports/json-subnets.pl?${search}",
    pagesize       => 50,
    source_columns => [
        { "data" => "name",            width => "90" },
        { "data" => "link_alloc_view", width => "30" },
        { "data" => "vlan" },
        { "data" => "template" },
        { "data" => "mask" },
        { "data" => "gateway" },
        { "data" => "description" }
    ],
    source_columndefs => [ { "searchable" => 1, } ],
);
$html->EndDTable( id => "subnets" );

$html->EndBlockTable();

$html->PageFooter();
