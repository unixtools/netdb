#!/usr/bin/perl

# Begin-Doc
# Name: disabled-hosts.pl
# Type: script
# Description: Report on hosts that are disabled
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
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $dhcp  = new NetMaint::DHCP;
my $html  = new NetMaint::HTML;
my $log   = new NetMaint::Logging;
my $hosts = new NetMaint::Hosts;

$log->Log();

$html->PageHeader( title => "Disabled Hosts Report" );

my $db = new NetMaint::DB;

$html->StartMailWrapper("Disabled Hosts");

$html->StartBlockTable("Disabled Hosts");
$html->StartInnerTable( "Host", "Date Disabled", "Comment" );

my $admin_options = $dhcp->GetAllAdminOptions();

foreach my $host ( sort( keys(%$admin_options) ) ) {
    my @options = $dhcp->GetAdminOptions($host);

    my $disabled = 0;
    my $ddate    = "";
    foreach my $option (@options) {
        my $config = $option->{option};
        my $tstamp = $option->{tstamp};
        if ( $config =~ /#\s*DISABLE/ ) { $disabled = 1; $ddate = $tstamp; }
    }
    next if ( !$disabled );

    my $info         = $hosts->GetHostInfo($host);
    my $admincomment = $info->{admin_comments};

    $html->StartInnerRow();
    print "<td>", $html->SearchLink_Host($host), "</td>\n";
    print "<td>$ddate</td>\n";
    print "<td>$admincomment</td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

