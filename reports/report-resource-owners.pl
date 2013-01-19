#!/usr/bin/perl

# Begin-Doc
# Name: report-resource-owners.pl
# Type: script
# Description: quick report of machine counts for resource accounts
# End-Doc

$| = 1;
use lib "/local/umrperl/libs";
use UMR::OracleObject;
use SNMP::Info;
use UMR::SysProg::SetUID;
use UMR::SysProg::ADSObject;

use lib "/local/netdb/libs";
use NetMaint::DB;

use strict;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";

my $ads = new UMR::SysProg::ADSObject();

my $qry = "select owner,count(*) from hosts group by owner order by owner";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ( $owner, $cnt ) = $db->SQL_FetchRow($cid) ) {
    my $info = $ads->GetAttributes($owner);
    my $dn;
    if ($info) {
        ($dn) = @{ $info->{distinguishedName} };
    }
    if ( $dn =~ /Resource/ ) {
        print "Resource\t$owner\t$cnt\n";
    }
}

$db->SQL_CloseQuery($cid);
