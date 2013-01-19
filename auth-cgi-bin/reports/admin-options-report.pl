#!/usr/bin/perl

# Begin-Doc
# Name: admin-options-report.pl
# Type: script
# Description: Report on host admin options that are set
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DHCP;
require NetMaint::DB;
require NetMaint::Logging;
require NetMaint::Hosts;

use UMR::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $dhcp  = new NetMaint::DHCP;
my $html  = new NetMaint::HTML;
my $log   = new NetMaint::Logging;
my $hosts = new NetMaint::Hosts;

$log->Log();

$html->PageHeader( title => "Admin Options Report" );

my $db = new NetMaint::DB;

$html->StartMailWrapper("Admin Options Report");

$html->StartBlockTable( "Admin Options Report", 1200 );
$html->StartInnerTable( "Admin Option", "Host", "Description", "Location", "Date" );

my $admin_options = $dhcp->GetAllAdminOptions();
my $info;

foreach my $host ( sort( keys(%$admin_options) ) ) {
    my @options = $dhcp->GetAdminOptions($host);
    foreach my $option (@options) {
        my $config = $option->{option};

        $config =~ s/^#\s*//gio;

        my $tstamp = $option->{tstamp};
        $info->{$config}->{$host} = [ $option->{tstamp} ];
    }
}

foreach my $config ( sort( keys( %{$info} ) ) ) {
    foreach my $host ( sort( keys( %{ $info->{$config} } ) ) ) {
        my ($tstamp) = @{ $info->{$config}->{$host} };

        my $hinfo = $hosts->GetHostInfo($host);
        if ( !$hinfo ) {
            $hinfo = {};
        }

        $html->StartInnerRow();
        print "<td>$config</td>\n";
        print "<td>", $html->SearchLink_Host($host), "</td>\n";
        print "<td>", $hinfo->{description}, "</td>\n";
        print "<td>", $hinfo->{location},    "</td>\n";
        print "<td>$tstamp</td>\n";
        $html->EndInnerRow();
    }
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

