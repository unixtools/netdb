#!/usr/bin/perl

# Begin-Doc
# Name: watch-arp.pl
# Type: script
# Description: continuously watch arp of various subnets
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/netdb/libs";
use Local::SetUID;
require NetMaint::DB;
use Sys::Hostname;
use Net::IP;

&SetUID("netdb");

my $server = hostname;
$server =~ s|\..*||gio;

my $debug = 0;

#
# Connect to db
#
my $db  = new NetMaint::DB;
my $qry = "replace into last_arp_ip(ip,ether,source,tstamp) values (?,?,?,now())";
my $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;

my %ip_to_ether = ();

while (1) {
    open( my $arp, "-|" ) || exec( "arp", "-an" );
    while ( defined( my $arpline = <$arp> ) ) {

        next if ( $arpline =~ /incomplete/o );
        next if ( $arpline =~ /00:00:00:00:00:00/o );

        # (10.155.2.161) at 00:1b:21:bf:6f:b4 [ether] on eth0
        if ( $arpline =~ m|.*\(([0-9\.]+)\) at ([0-9a-f:]+) | ) {
            my $ip  = $2;
            my $eth = $2;

            $db->SQL_ExecQuery( $cid, $ip, $ether, $server ) || $db->SQL_Error("inserting $ip, $ether: $qry") && die;
        }
    }
    close($arp);

    sleep(15);
}
