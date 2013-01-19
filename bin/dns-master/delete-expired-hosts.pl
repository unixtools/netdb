#!/usr/bin/perl

# Begin-Doc
# Name: delete-expired-hosts.pl
# Type: script
# Description: purge hosts that have not been seen on the network
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use lib "/local/netdb/libs";
require NetMaint::DB;
require NetMaint::Register;
require NetMaint::Logging;
require NetMaint::DNS;
require NetMaint::DHCP;

my $db  = new NetMaint::DB;
my $reg = new NetMaint::Register;
my $log = new NetMaint::Logging;

my $dhcp = new NetMaint::DHCP;
my $dns  = new NetMaint::DNS;

$dhcp->BlockUpdates();
$dns->BlockUpdates();

my $qry = "select host from hosts where purge_date < now() and "
    . "type in ('desktop','printer','guest') order by purge_date";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);

my @hosts;
while ( my ($host) = $db->SQL_FetchRow($cid) ) {
    push( @hosts, $host );
}
$db->SQL_CloseQuery($cid);

if ( $#hosts < 0 ) {
    exit;
}

if ( $ARGV[0] ne "-noverify" ) {
    foreach my $host (@hosts) {
        print "$host:\n";
    }

    if ( $#hosts > 0 ) {
        print "expire this batch? ";
        my $answer = <>;
        if ( $answer !~ /^[yY]/o ) {
            exit;
        }
    }
}

foreach my $host (@hosts) {
    print "$host:\n";

    $log->Log(
        action => "expiring host",
        host   => $host,
    );

    $reg->DeleteHost($host);
}

# Will automatically trigger an update if anything has been changed
$dns->UnblockUpdates();
$dhcp->UnblockUpdates();

