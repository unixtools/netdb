#!/usr/bin/perl

# Begin-Doc
# Name: build-dns-slave-conf.pl
# Type: script
# Description: generate config file for dns slave host
# End-Doc

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
require NetMaint::DNSZones;
require NetMaint::Error;

use strict;

my $error    = new NetMaint::Error;
my $dnszones = new NetMaint::DNSZones;

# Get list of zones
my @zones;
$error->clear();
@zones = $dnszones->GetZones();
$error->check_and_die();

my $tmpfile = "/local/bind/etc/named.conf.host";
open( my $out, ">${tmpfile}.tmp" );
print $out "#\n";
print $out "# Do not edit - run /local/netdb/bin/dns/build-dns-slave-conf.pl\n";
print $out "#\n";
print $out "\n";

foreach my $zone ( sort(@zones) ) {
    print $out <<EOF;
zone "$zone" {
    type slave;
    file "slave/$zone";
    masters { 131.151.245.17; };
    notify no;
};
EOF
    print $out "\n";
    if ( !-e "/local/bind/data/slave/$zone" ) {
        print "Added new zone: $zone\n";
    }
}

print $out "\n\n";
print $out <<EOM;
#
# Example to forward zone to specific upstream server.
#
# zone "zonename" {
#    type forward;
#    forward only;
#    forwarders { 8.8.8.8; 8.8.4.4; };
#};
#
EOM

close($out);
rename( $tmpfile . ".tmp", $tmpfile );

system("/local/bind/sbin/rndc reload");
