#!/usr/bin/perl

# Begin-Doc
# Name: quota-usage-report.pl
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

&PrivSys_RequirePriv("netdb-user");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Quota Usage" );

my $db     = new NetMaint::DB;
my $dhcp   = new NetMaint::DHCP;
my $dns    = new NetMaint::DNS;
my $access = new NetMaint::Access;

my $quotas = $access->GetAllRegistrationQuotas();

$html->StartBlockTable( "Quota Report", 750 );
$html->StartInnerTable( "User", "Quota", "Count" );

my $qry = "select b.owner,count(*) from ethers a, hosts b where a.name=b.host group by b.owner";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
my %cnt;

while ( my ( $user, $cnt ) = $db->SQL_FetchRow($cid) ) {
    $cnt{$user} = $cnt;
}
$db->SQL_CloseQuery($cid);

my $qry = "select distinct owner from hosts order by owner";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ($user) = $db->SQL_FetchRow($cid) ) {
    my $quota = $access->GetDefaultRegistrationQuota($user);
    my $cnt   = $cnt{$user};

    next if ( $cnt < $quota );

    $html->StartInnerRow();

    print "<td>$user</td>";
    print "<td align=right>$quota</td>";
    print "<td align=right>$cnt</td>";

    $html->EndInnerRow();
}
$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();
