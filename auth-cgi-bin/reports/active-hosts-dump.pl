#!/usr/bin/perl

# Begin-Doc
# Name: active-hosts-dump.pl
# Type: script
# Description: Report on active registered hosts
# End-Doc

use strict;

use lib "/local/perllib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::DB;
require NetMaint::Logging;

use Local::PrivSys;
use Local::OracleObject;
use Text::CSV;
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
print "Content-Disposition: attachment; filename=active-hosts.csv\n";
&HTMLContentType("text/plain");

my $db  = new NetMaint::DB;
my $log = new NetMaint::Logging;

my $rpt = new Local::OracleObject;
$rpt->SQL_OpenDatabase("rpt*") || $rpt->SQL_Error("open db") && die;

$log->Log();

my $psqry = "
select flat.dept
from 
  core_hr_eff.ps_um_employees pue
  join core_sso.sso_email ssoe on (ssoe.emplid=pue.emplid)
  left outer join core_hr_eff.ps_um_hr_flat_tree flat on (pue.deptid = flat.deptid and pue.business_unit=flat.business_unit)
where 
  pue.empl_type_um <> 'S'  and pue.empl_rcd != 99 and 
  pue.empl_status not in ('T','R','D') and 
  ssoe.userid = ?
";
my $pscid = $rpt->SQL_OpenBoundQuery($psqry);

my $qry = "select h.owner,h.host,h.type,e.ether,h.location,h.description,h.admin_comments,
        greatest(lth.tstamp,lte.tstamp)
from hosts h
join ethers e on (h.host=e.name)
left outer join last_touch_host lth on (h.host=lth.host)
left outer join last_touch_ether lte on (e.ether=lte.ether)
order by h.owner,h.host
";

my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);

my @cols = qw(deptid index owner host type ether location description admin_comments last_touch);
my $csv  = Text::CSV->new();

$csv->combine(@cols);
print $csv->string(), "\n";

my %deptcache = ();
my $idx       = 0;
my $lastowner = "";
while ( my @row = $db->SQL_FetchRow($cid) ) {
    my ( $owner, $host, $type, $ether, $lasttouch ) = @row;
    $row[$#row] =~ s/ .*//go;

    if ( $owner ne $lastowner ) {
        $idx = 0;
    }
    $lastowner = $owner;
    $idx++;

    if ( !exists( $deptcache{$owner} ) ) {
        $rpt->SQL_ExecQuery( $pscid, $owner );
        ( $deptcache{$owner} ) = $rpt->SQL_FetchRow($pscid);
    }

    next if ( !$deptcache{$owner} );

    $csv->combine( $deptcache{$owner}, $idx, @row );
    print $csv->string(), "\n";
}
$db->SQL_CloseQuery($cid);
$rpt->SQL_CloseQuery($pscid);
