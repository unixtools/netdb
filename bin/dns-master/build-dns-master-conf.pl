#!/usr/bin/perl

# Begin-Doc
# Name: build-dns-master-conf.pl
# Type: script
# Description: generate config file for dns master host
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

require NetMaint::DNSZones;
require NetMaint::Error;

my $error    = new NetMaint::Error;
my $dnszones = new NetMaint::DNSZones;

# Get list of zones
my @zones;
$error->clear();
@zones = $dnszones->GetZones();
$error->check_and_die();

my %sign = map { $_ => 1 } $dnszones->GetSignableZones();

my $tmpfile = "/local/bind/etc/named.conf.host";
open( my $out, ">${tmpfile}.tmp" );
print $out "#\n";
print $out "# Do not edit - run /local/netdb/bin/dns/build-dns-master-conf.pl\n";
print $out "#\n";
print $out "\n";

foreach my $zone ( sort(@zones) ) {
    my $file = "/local/bind/data/source/$zone";
    my $src  = "source/$zone";
    if ( $sign{$zone} ) {
        $file .= ".signed";
        $src  .= ".signed";
    }

    if ( !-e $file ) {
        print "Skipping zone $zone - missing source zone file.\n";
        next;
    }

    my @notify = ();

    # ip address list

    print $out <<EOF;
zone "$zone" {
    type master;
    file "$src";
    check-names ignore;
EOF

    if ( scalar(@notify) > 0 ) {
        print $out " also-notify {";

        foreach my $ip (@notify) {
            print $out " " x 8, "$ip;\n";
        }

        print $out " };\n";
    }

    print $out <<EOF;
};
EOF

    print $out "\n";
}
close($out);
rename( $tmpfile . ".tmp", $tmpfile );

system("/local/bind/sbin/rndc reload");
