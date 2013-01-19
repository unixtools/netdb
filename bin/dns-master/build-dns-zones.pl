#!/usr/bin/perl

# Begin-Doc
# Name: build-dns-zones.pl
# Type: script
# Description: generate the bind dns zone config files
# End-Doc

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
require NetMaint::DNSZones;
require NetMaint::Error;

use strict;

my $error = new NetMaint::Error;

my $dnszones = new NetMaint::DNSZones;

# Get list of zones
my @zones;
if ( $ARGV[0] eq "-force" ) {
    $error->clear();
    $dnszones->UpdateAllSOA();    # make sure serial numbers are incremented
    $error->check_and_die();

    $error->clear();
    @zones = $dnszones->GetZones();
    $error->check_and_die();
}
else {
    $error->clear();
    @zones = $dnszones->GetChangedZones();
    $error->check_and_die();
}

my %sign = map { $_ => 1 } $dnszones->GetSignableZones();

print "Zones: ", join( ", ", @zones ), "\n";

my $base          = "/local/config/data";
my $lastbase      = "/local/config/data-last";
my $zones_updated = 0;

foreach my $zone ( sort(@zones) ) {
    my $fname     = "${base}/${zone}";
    my $lastfname = "${lastbase}/${zone}";

    unlink( $lastfname . ".tmp" );
    open( my $tmpfh, ">${lastfname}.tmp" );
    open( my $infh,  $fname );
    while ( defined( my $line = <$infh> ) ) {
        print $tmpfh $line;
    }
    close($infh);
    close($tmpfh);

    unlink($lastfname);
    rename( $lastfname . ".tmp", $lastfname );

    unlink( $fname . ".tmp" );
    open( my $tmpfh, ">${fname}.tmp" );
    print $tmpfh "\$ORIGIN $zone.\n";
    print $tmpfh "\$TTL 300\n";

    # Need to add dnssec record types here for subzone signing
    my @types = ();
    if ( $zone =~ /in-addr\.arpa$/ ) {
        @types = ( "SOA", "NS", "PTR" );
    }
    elsif ( $zone =~ /ip6\.arpa$/ ) {
        @types = ( "SOA", "NS", "PTR" );
    }
    else {
        @types = ( "SOA", "NS", "SRV", "TXT", "A", "AAAA", "MX", "CNAME" );
    }

    my %counts = ();

    # First get all SOA records
    foreach my $rectype (@types) {

        $error->clear();
        my $recs = $dnszones->Get_Zone_Records( $zone, $rectype );
        $error->check_and_die();

        my $cnt = scalar(@$recs);

        if ( $cnt > 0 ) {
            print $tmpfh ";\n";
            print $tmpfh "; $rectype Records - $zone\n";
            print $tmpfh ";\n";

            foreach my $rec (@$recs) {
                print $tmpfh $dnszones->Format_Zone_Record($rec), "\n";
            }
            print $tmpfh "\n\n";
        }

        $counts{$rectype} = $cnt;
    }
    close($tmpfh);

    print "$zone: Counts(";
    foreach my $rectype (@types) {
        print " ${rectype}=", int( $counts{$rectype} );
    }
    print ")\n";

    open( my $diffh, "-|" ) || exec( "/usr/bin/diff", "-I", " IN SOA ", "-u", $lastfname, "${fname}.tmp" );
    my $diffcnt = 0;
    while ( defined( my $line = <$diffh> ) ) {
        $diffcnt++;
        print $line;
    }
    close($diffh);
    if ( $sign{$zone} ) {

        # Need to put some code in here for checking currency of keys to force resigning
    }

    if ( $diffcnt == 0 ) {
        if ( $ARGV[0] ne "-force" ) {
            print "  No changes found. Not installing new version.\n";
            unlink("${fname}.tmp");
            next;
        }
        else {
            print "  No changes found. Force loading zone.\n";
        }
    }
    print "\n";

    my $errorcnt = 0;
    print "  Checking new zone file for validity:\n";
    # -k ignore - ignore underscores
    open( my $checkh, "-|" ) || exec( "/local/bind/sbin/named-checkzone", "-k", "ignore", $zone, "${fname}.tmp" );
    my $saw_serial = 0;
    while ( defined( my $line = <$checkh> ) ) {
        if ( $line =~ /loaded serial/ ) {
            $saw_serial = 1;
        }
        print $line;
    }
    close($checkh);
    my $errorstat = $?;
    if ( !$saw_serial ) {
        print "  Zone failed test load (Status: $errorstat).\n";
        unlink( $fname . ".tmp" );
        next;
    }
    elsif ( $errorstat != 0 ) {
        print "  Zone failed syntax check (Status: $errorstat)\n";
        unlink( $fname . ".tmp" );
        next;
    }
    print "\n";

    # Now count lines in done
    open( my $checkh, "${fname}.tmp" );
    my $linecount = 0;
    while ( defined( my $line = <$checkh> ) ) {
        $linecount++;
    }
    close($checkh);

    # Should move this to database in dns_soa...
    my @stat = stat("${fname}.tmp");
    if ( $stat[7] < 150 ) {
        print "Zone ($zone) file too small (", $stat[7], " bytes). Not installing new version.\n";
    }
    elsif ( $linecount < 4 ) {
        print "Zone($zone) file too small (", $linecount, " lines). Not installing new version.\n";
    }
    else {
        print "Zone file acceptable. Installing new version.\n";
        rename( $fname . ".tmp", $fname );

        my $bindbase = "/local/bind/data/source";
        my $realfile = $bindbase . "/" . $zone;
        my $tmpfile  = $realfile . ".tmp";
        unlink($tmpfile);
        open( my $inzone,  $fname );
        open( my $outzone, ">" . $tmpfile );
        while ( defined( my $line = <$inzone> ) ) {
            print $outzone $line;
        }
        close($outzone);
        close($inzone);
        rename( $tmpfile, $realfile );

        $zones_updated++;
    }

    unlink( $fname . ".tmp" );
    print "\n";

    #
    #
    #
    if ( $sign{$zone} ) {
        print "Signing zone $zone:\n";
        open( my $signzone, "-|" ) || exec(
            "/local/bind/sbin/dnssec-signzone", "-T",                     3600,
            "-S",                               "-K",                     "/local/bind/data/keys",
            "-d",                               "/local/bind/data/dsset", "-g",
            "-r",                               "/dev/urandom",           "-P",
            "-t",                               "-u",                     "-o",
            $zone,                              "-f",                     "${fname}.signed.tmp",
            $fname
        );
        my $sigs = 0;
        while ( defined( my $line = <$signzone> ) ) {
            print $line;
            if ( $line =~ /Signatures per second/o ) {
                $sigs = 1;
            }
        }
        close($signzone);
        if ($sigs) {
            print "Signing completed, moving signed zone into place (${fname}.signed.tmp to ${fname}.signed).\n";
            rename( "${fname}.signed.tmp", "${fname}.signed" );

            my $bindbase = "/local/bind/data/source";
            my $realfile = $bindbase . "/" . $zone . ".signed";
            my $tmpfile  = $realfile . ".tmp";
            unlink($tmpfile);
            open( my $inzone,  $fname . ".signed" );
            open( my $outzone, ">" . $tmpfile );
            while ( defined( my $line = <$inzone> ) ) {
                print $outzone $line;
            }
            close($outzone);
            close($inzone);
            rename( $tmpfile, $realfile );

        }
        else {
            print "Failed to get results of signing, skipping update of signed zone.\n";
            next;
        }
    }

}

if ( $zones_updated > 0 ) {
    print "Triggering named reload.\n";
    system( "/local/bind/sbin/rndc", "reload" );
}
