#!/usr/bin/perl

# Begin-Doc
# Name: update-mac-block-table.pl
# Type: script
# Description: update mac block table with recently seen mac addresses for a host
# End-Doc

use strict;

$| = 1;
use lib "/local/umrperl/libs";
use lib "/local/netdb/libs";
use NetMaint::DB;

print "Starting mac block table update at ", scalar(localtime), "\n";

print "Opening database...\n";
my $db = new NetMaint::DB || print "failed to open db!" && die;
print "Done.\n";

# First get the list of ones that we know the subnet/vlan for

my $qry = "select 
	distinct c.vlan,a.ether
from 
	(select distinct ether,ip from dhcp_acklog where unix_timestamp(now())-unix_timestamp(tstamp) < 24*60*60) a,
	ip_alloc b, subnets c, ethers e, admin_host_options ho
where
	ho.config = '# DISABLE' and
	e.name = ho.host and
	a.ether = e.ether and
	b.ip = a.ip and
	c.subnet = b.subnet
order by
	c.vlan, a.ether";

print "Scanning from dhcp_acklog:\n";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
my %block;
my %seen;
while ( my ( $vlan, $ether ) = $db->SQL_FetchRow($cid) ) {

    print ".";
    $block{$ether}->{$vlan} = 1;
    $seen{$ether} = 1;
}
$db->SQL_CloseQuery($cid);
print "Done.\n";

# Also include results based on arp scan table

my $qry = "select
        distinct c.vlan,a.ether
from
        arpscan a, ip_alloc b, subnets c, ethers e, admin_host_options ho
where
	unix_timestamp(now()) - unix_timestamp(a.tstamp) < 7*24*60*60 and
        ho.config = '# DISABLE' and
        e.name = ho.host and
        a.ether = e.ether and
        b.ip = a.ip and
        c.subnet = b.subnet
order by
        c.vlan, a.ether";

print "Scanning from arpscan:\n";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
while ( my ( $vlan, $ether ) = $db->SQL_FetchRow($cid) ) {

    print ".";
    $block{$ether}->{$vlan} = 1;
    $seen{$ether} = 1;
}
$db->SQL_CloseQuery($cid);
print "Done.\n";

# Also include results based on lastack table

my $qry = "select
        distinct c.vlan,a.ether
from
        dhcp_lastack a, ip_alloc b, subnets c, ethers e, admin_host_options ho
where
        ho.config = '# DISABLE' and
        e.name = ho.host and
        a.ether = e.ether and
        b.ip = a.ip and
        c.subnet = b.subnet
order by
        c.vlan, a.ether";

print "Scanning from dhcp_lastack:\n";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
while ( my ( $vlan, $ether ) = $db->SQL_FetchRow($cid) ) {

    print ".";
    $block{$ether}->{$vlan} = 1;
    $seen{$ether} = 1;
}
$db->SQL_CloseQuery($cid);
print "Done.\n";

# Now get the others - if we see one of these, leave it in place, but we cannot add a new
# entry, since we don't know what subnets to add for.

my $qry = "select
        distinct a.ether
from
        ethers a, admin_host_options ho
where
        ho.config = '# DISABLE' and
        a.name = ho.host 
order by
        a.ether";

print "Scanning full block list without current IPs:\n";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
my %dont_remove;
while ( my ($ether) = $db->SQL_FetchRow($cid) ) {

    print ".";
    $dont_remove{$ether} = 1;
}
$db->SQL_CloseQuery($cid);
print "Done.\n";

#
# Now that we've built the info list, update the oracle table
#
print "Flagging old entries...\n";
my $qry = "update mac_block set updateflag=0";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;
print "Done.\n";

my $qry = "insert into mac_block(ether,vlan,updateflag) values (?,?,1)";
my $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;

print "Inserting new entries...\n";
foreach my $eth ( keys(%block) ) {
    foreach my $vlan ( keys( %{ $block{$eth} } ) ) {
        $db->SQL_ExecQuery( $cid, $eth, $vlan ) || $db->SQL_Error($qry);
    }
}
print "Done.\n";

print "Inserting non-removal entries without current IP...\n";
foreach my $eth ( keys(%dont_remove) ) {
    $db->SQL_ExecQuery( $cid, $eth, '' ) || $db->SQL_Error($qry);
}
print "Done.\n";

$db->SQL_CloseQuery($cid);

print "Clearing old entries...\n";
my $qry = "delete from mac_block where updateflag=0";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry);
print "Done.\n";

print "Mac block table update complete at ", scalar(localtime), "\n";
