#!/usr/bin/perl

# Begin-Doc
# Name: update-ignored-ethers.pl
# Type: script
# Description: add any ethers that are sitting on unreg subnet to the table of ignored ethers
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use Local::SetUID;
use NetMaint::DB;
use NetMaint::DHCP;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";
my $updates = 0;

print "Scanning for new ethers to ignore...\n";
my $qry = "
select x.ether,x.ip,x.mint,x.maxt,x.cnt from (
    select ether,ip,count(*) cnt,min(tstamp) mint,max(tstamp) maxt from dhcp_acklog group by ether,ip) x
where x.ip in (select ip from ip_alloc where type='unreg')
and x.ether not in (select ether from ignored_ethers)
and x.cnt > 5
and x.maxt > date_sub(x.mint,interval 6 hour)
and x.maxt > date_sub(now(),interval 6 hour)
";

my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
while ( my ($ether) = $db->SQL_FetchRow($cid) ) {
    print "Adding ether to ignored_ethers list: $ether\n";
    my $qry = "insert into ignored_ethers(ether,tstamp) values (?,now())";
    $db->SQL_ExecQuery( $qry, $ether ) || $db->SQL_Error($qry) && next;

    $updates++;
}
$db->SQL_CloseQuery($cid);

print "Scanning for ignored ethers that have been registered...\n";

# can remove the autounreg as soon as we've put this in service
my $qry
    = "select ether from ignored_ethers where ether in (select ether from ethers where name not like '%autounreg%')";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
while ( my ($ether) = $db->SQL_FetchRow($cid) ) {
    print "Removing ether from ignored_ethers list: $ether\n";
    my $qry = "delete from ignored_ethers where ether=?";
    $db->SQL_ExecQuery( $qry, $ether ) || $db->SQL_Error($qry) && next;

    $updates++;
}
$db->SQL_CloseQuery($cid);

print "Scanning for ignored ethers that haven't been seen in 7 days...\n";

# Now clean entries that aren't showing up any more - haven't seen in 7 days, remove from the ignore list
my $qry
    = "select i.ether,max(d.tstamp) from ignored_ethers i join dhcp_acklog d on (i.ether=d.ether) group by i.ether having max(d.tstamp) < date_sub(now(),interval 7 day)";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
while ( my ($ether) = $db->SQL_FetchRow($cid) ) {
    print "Removing expired ether from ignored_ethers list: $ether\n";
    my $qry = "delete from ignored_ethers where ether=?";
    $db->SQL_ExecQuery( $qry, $ether ) || $db->SQL_Error($qry) && next;

    $updates++;
}
$db->SQL_CloseQuery($cid);

if ($updates) {
    print "Triggering DHCP server update...\n";
    my $dhcp = new NetMaint::DHCP;
    $dhcp->TriggerUpdate();
}
