#!/usr/bin/perl

# Begin-Doc
# Name: update-thresholds.pl
# Type: script
# Description: update threshold values to approximately 75%
# End-Doc

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use NetMaint::Config;
require NetMaint::DNSZones;
require NetMaint::Error;

use strict;

my $error    = new NetMaint::Error;
my $dnszones = new NetMaint::DNSZones;
my $db       = new NetMaint::DB;

my $base = "/local/config/data";

my $thresh = $dnszones->GetThresholds();
if ( ref($thresh) ne "HASH" ) {
    die "Could not retrieve thresholds.\n";
}
my @zones = sort( keys(%$thresh) );

foreach my $zone ( sort(@zones) ) {
    my $fname = "${base}/${zone}";

    open( my $checkh, $fname );
    my $lines = 0;
    while ( defined( my $line = <$checkh> ) ) {
        $lines++;
    }
    close($checkh);

    # Should move this to database in dns_soa...
    my @stat = stat($fname);
    my $size = $stat[7];

    if ( !$size || !$lines ) {
        print "Skipping $zone.\n";
        next;
    }

    my $target_size  = int( ( .75 * $size ) / 100 ) * 100;
    my $target_lines = int( ( .75 * $lines ) / 100 ) * 100;

    if ( $lines < 250 ) {
        $target_lines = int( ( .75 * $lines ) / 10 ) * 10;
    }

    print "$zone:\n";
    print "  File Size: $size\n";
    print "  Line Count: $lines\n";
    print "  Size Threshold: ",       $thresh->{$zone}->{size},  "\n";
    print "  Line Count Threshold: ", $thresh->{$zone}->{lines}, "\n";
    print "  Target Size Threshold: ",       $target_size,  "\n";
    print "  Target Line Count Threshold: ", $target_lines, "\n";
    print "\n\n";

    if ( $target_size != $thresh->{$zone}->{size} ) {
        my $qry = "update dns_soa set thresh_size=? where zone=?";

        $db->SQL_ExecQuery( $qry, $target_size, $zone ) || $db->SQL_Error( $qry . " ($target_size, $zone)" );
    }
    if ( $target_lines != $thresh->{$zone}->{lines} ) {
        my $qry = "update dns_soa set thresh_lines=? where zone=?";

        $db->SQL_ExecQuery( $qry, $target_lines, $zone ) || $db->SQL_Error( $qry . " ($target_lines, $zone)" );
    }
}

