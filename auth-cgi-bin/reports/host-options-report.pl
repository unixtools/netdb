#!/usr/bin/perl

# Begin-Doc
# Name: host-options-report.pl
# Type: script
# Description: Report on dhcp host options by host
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DHCP;
require NetMaint::DB;
require NetMaint::Logging;
require NetMaint::Hosts;

use Local::PrivSys;
&PrivSys_RequirePriv("netdb-admin");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $dhcp  = new NetMaint::DHCP;
my $html  = new NetMaint::HTML;
my $log   = new NetMaint::Logging;
my $hosts = new NetMaint::Hosts;

$log->Log();

$html->PageHeader( title => "Host Options Report" );

my $db = new NetMaint::DB;

my @links       = ();
my %option_info = $dhcp->GetOptionInfo();
foreach my $option ( sort( keys(%option_info) ) ) {
    push( @links, "<a href=\"?option=$option\">$option - " . $option_info{$option} . "</a>" );
}

$html->StartBlockTable("Host Option Searches");
$html->StartInnerTable();
foreach my $link (@links) {
    $html->StartInnerRow();
    print "<td>$link</td>\n";
    $html->EndInnerRow();
}
$html->EndInnerTable();
$html->EndBlockTable();

if ( $rqpairs{option} ) {
    $html->StartMailWrapper("Host Options Report");
    $html->StartBlockTable( "Host Options Report", "1200" );
    $html->StartInnerTable( "Host Option", "Host", "Description", "Location", "Date" );

    my $host_options = $dhcp->GetAllHostOptions();

    my $info;
    foreach my $host ( sort( keys(%$host_options) ) ) {

        my $tmp = join( "", @{ $host_options->{$host} } );
        next if ( index( $tmp, $rqpairs{option} ) < 0 );

        my @options = $dhcp->GetHostOptions($host);
        foreach my $option (@options) {
            my $config = $option->{option};

            $config =~ s/^#\s*//gio;
            next if ( index( $config, $rqpairs{option} ) < 0 );

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
}

$html->EndMailWrapper();

$html->PageFooter();

