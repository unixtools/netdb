#!/usr/bin/perl

# Begin-Doc
# Name: json-extract-dhcp-usage.pl
# Type: script
# Description: Report on current dhcp usage in json format for use by remote web scripts
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;
use Local::AuthSrv;
use Data::Dumper;
use JSON;

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DB;
require NetMaint::Logging;

my $db = new NetMaint::DB;

# Now make sure every subnet shows up in list:
my $net    = new NetMaint::Network;
my $sninfo = $net->GetSubnets();

my $info = {};

#
# Load mapping info for ip to subnet
#
my $qry        = "select ip,subnet,type from ip_alloc";
my $cid        = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
my %ip_to_sn   = ();
my %ip_to_type = ();
my %types      = ();
while ( my ( $ip, $sn, $type ) = $db->SQL_FetchRow($cid) ) {
    $ip_to_sn{$ip}   = $sn;
    $ip_to_type{$ip} = $type;
    $types{$type}    = 1;
}
$db->SQL_CloseQuery($cid);

#
# Load allocation by type
#
my $qry = "select subnet,type,count(*) from ip_alloc group by subnet, type";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
while ( my ( $sn, $type, $cnt ) = $db->SQL_FetchRow($cid) ) {
    $info->{$sn}->{$type}->{allocated} += $cnt;
}
$db->SQL_CloseQuery($cid);

#
# Make sure every type has at least an entry with 0 allocated
#
foreach my $sn ( keys(%$sninfo) ) {
    foreach my $type ( keys(%types) ) {
        $info->{$sn}->{$type}->{allocated} += 0;
    }
}

#
# Now retrieve the leases file and summarize data
#
my $tmpinfo;
my $ip;
my %seen;

open( my $in, "/local/dhcp-root/etc/dhcpd.leases" );
while ( defined( my $line = <$in> ) ) {
    chomp($line);

    if ( $line =~ /^lease\s+([\d\.]+)\s+{/o ) {
        if ($tmpinfo) {
            undef $tmpinfo;
        }

        $ip      = $1;
        $tmpinfo = {};
    }
    elsif ( $line =~ /^}/o ) {
        my $state = $tmpinfo->{state};
        my $ether = $tmpinfo->{ether};

        my $sn   = $ip_to_sn{$ip}   || "unknown";
        my $type = $ip_to_type{$ip} || "unknown";

        if ( !$seen{"$ip/$state"} ) {
            $info->{$sn}->{$type}->{$state}++;
            $seen{"$ip/$state"} = 1;
        }
        undef $tmpinfo;
    }
    elsif ( $line =~ /^\s+binding state (.*?);/o ) {
        $tmpinfo->{state} = $1;
    }
    elsif ( $line =~ /^\s+hardware ethernet (.*?);/o ) {
        my $eth = uc $1;
        $eth =~ s/://go;
        $tmpinfo->{ether} = $eth;
    }
}
print encode_json($info);
