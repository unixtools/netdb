#!/usr/bin/perl

# Begin-Doc
# Name: quota-report.pl
# Type: script
# Description: report on quota usage and quota values
# End-Doc

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use Local::SetUID;
use Local::HTMLUtil;
use Local::PrivSys;
require NetMaint::DB;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::DBCache;
require NetMaint::Access;
require NetMaint::HTML;
require NetMaint::Logging;

&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "User Quota Report" );

my $db     = new NetMaint::DB;
my $dhcp   = new NetMaint::DHCP;
my $dns    = new NetMaint::DNS;
my $access = new NetMaint::Access;

my $quotas = $access->GetAllRegistrationQuotas();

$html->StartBlockTable( "Quota Report", 750 );
$html->StartInnerTable( "User", "Quota", "Default", "Count", "Comment" );

foreach my $user ( sort( keys(%$quotas) ) ) {
    my $quota = $quotas->{$user};

    my $defquota = $access->GetDefaultRegistrationQuota($user);

    my $cnt = $access->GetUsedQuota($user);

    $html->StartInnerRow();

    print "<td>$user</td>";
    print "<td align=right>$quota</td>";
    print "<td align=right>$defquota</td>";
    print "<td align=right>$cnt</td>";

    print "<td>";
    if ( $cnt == 0 && $defquota == 0 ) {
        print "delete-to-default-nohosts";
    }
    elsif ( $quota == $defquota ) {
        print "delete-to-default-samenumber";
    }
    elsif ( $quota != $defquota && $quota > 0 && $defquota > ( $cnt + 5 ) ) {
        print "delete-to-default-excessive";
    }
    elsif ( $quota != $defquota && $quota > 0 && $defquota == 0 && $cnt > 0 ) {
        print "trim-to-cnt-hosts-or-delete";
    }
    print "</td>\n";

    $html->EndInnerRow();
}
$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();
