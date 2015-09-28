#!/usr/bin/perl

# Begin-Doc
# Name: admin-options-report.pl
# Type: script
# Description: Report on host admin options that are set
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

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

$html->PageHeader( title => "Admin Comments Report" );

my $db = new NetMaint::DB;

$html->StartMailWrapper("Admin Comments Report");

my $info     = {};
my $comments = $hosts->GetAllAdminComments();
my $owners   = $hosts->GetAllHostOwners();

foreach my $host ( keys(%$comments) ) {
    $info->{$host}->{comments} = $comments->{$host};
    $info->{$host}->{owner}    = $owners->{$host};
}

$html->StartBlockTable("Admin Comments Report");
$html->StartInnerTable( "Host", "Owner", "Comments" );
foreach my $host (
    sort { $info->{$a}->{comments} cmp $info->{$b}->{comments} }
    keys %$info
    )
{
    my $comments = $info->{$host}->{comments};
    my $owner    = $info->{$host}->{owner};

    $html->StartInnerRow();
    print "<td>", $html->SearchLink_Host($host), "</td>\n";
    print "<td>$owner</td>\n";
    print "<td>$comments</td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

