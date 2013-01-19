#!/usr/bin/perl

# Begin-Doc
# Name: load-scesm-statics.pl
# Type: script
# Description: load static ip allocations into sce subscribers database
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use Local::SetUID;
require NetMaint::DB;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::DBCache;

&SetUID("netdb");

my $db   = new NetMaint::DB;
my $dhcp = new NetMaint::DHCP;
my $dns  = new NetMaint::DNS;

my $cache = new NetMaint::DBCache;

my $qry = "select ia.ip,ia.host,h.type,h.owner
    from 
        ip_alloc ia, hosts h 
    where
        ia.type='static' and
        ia.host=h.host";

my %mappings;

print "Loading static address info from netdb...\n";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
while ( my ( $ip, $host, $type, $owner ) = $db->SQL_FetchRow($cid) ) {

    # No point in even processing these since they'll never make it to I1
    next if ( $ip =~ /^10\./ || $ip =~ /^192\.168\./ || $ip =~ /^172./ );

    my $subscriber = "";

    my $hostsub = $host;
    $hostsub =~ s/\./-/go;
    $hostsub =~ s/-[ptd]\d+-srv//go;
    $hostsub =~ s/-srv-mst-edu//go;
    $hostsub =~ s/-network-mst-edu//go;
    $hostsub =~ s/-vpn-mst-edu//go;
    $hostsub =~ s/-mst-edu//go;
    $hostsub =~ s/-iscsi\d*$//go;
    $hostsub =~ s/-hba\d*$//go;
    $hostsub =~ s/-eth\d*$//go;
    $hostsub =~ s/-vmotion\d*$//go;

    # This will be very inefficient till it's make into a single stream with continuous calls
    if ( $type eq "server" ) {
        $subscriber = "srv-" . $hostsub;
    }
    elsif ( $type eq "network" && $host =~ /\.vpn\.mst\.edu/o ) {
        $subscriber = "vpn-" . $hostsub;
    }
    elsif ( $type eq "network" && $host =~ /lwapp/ ) {
        $subscriber = "net-lwapp";
    }
    elsif ( $type eq "network" && $host =~ /tlck/ ) {
        $subscriber = "net-tlck";
    }
    elsif ( $type eq "network" ) {
        $subscriber = "net-" . $hostsub;
    }
    elsif ( $owner && $host =~ /^rc\d\d[a-z](.*)\.[a-z]+\.[a-z]+\.[a-z]+$/o ) {
        $subscriber = "clc-" . lc $1;
    }
    elsif ($owner) {
        $subscriber = "user-" . lc $owner;
    }
    else {
        $subscriber = "unk-static-$type";
    }

    $mappings{$subscriber}->{$ip} = 1;
}
print "Done.\n";

#
# Load in existing subscribers
#
my $cnt = 0;
print "Loading existing subscribers...\n";
open( my $subfh, "/local/scesm/bin/list-subscribers subscribers|" );
my %have_subscriber;
while ( defined( my $line = <$subfh> ) ) {
    chomp($line);
    $have_subscriber{$line} = time;
    $cnt++;
    if ( $cnt % 250 == 0 ) {
        print "[$cnt]\n";
    }
}
close($subfh);
print "Done. ($cnt total)\n";

#
# Load in existing mappings
#
print "Loading existing mappings...\n";
open( my $mapfh, "/local/scesm/bin/list-mappings subscribers|" );
my $cnt = 0;
my %have_mapping;
while ( defined( my $line = <$mapfh> ) ) {
    chomp($line);
    my ( $subscriber, $ipmask ) = split( ' ', $line );
    if ( $ipmask =~ m|^(.+)/32|o ) {
        $have_mapping{$subscriber}->{$1} = 1;
    }
    $cnt++;
    if ( $cnt % 250 == 0 ) {
        print "[$cnt]\n";
    }
}
close($mapfh);
print "Done. ($cnt total)\n";

#
# Add any missing mappings
#
print "Refreshing mappings...\n";
open( my $loadfh, "|-" ) || exec("/local/scesm/bin/batch-cmd");
select($loadfh);
$| = 1;
select(STDOUT);

my $lifetime = 4 * 24 * 60 * 60;
foreach my $subscriber ( sort keys(%mappings) ) {
    if ( !$have_subscriber{$subscriber} ) {
        print "Adding subscriber: $subscriber\n";
        print $loadfh "add-subscriber $subscriber\n";
        $have_subscriber{$subscriber} = 1;

        if ( $subscriber =~ /^srv/ ) {
            print "Setting subscriber package for $subscriber.\n";

            # 6 is special package for unlimited servers
            print $loadfh "set-subscriber-property $subscriber packageId 6\n";
        }
    }

    foreach my $ip ( sort keys( %{ $mappings{$subscriber} } ) ) {
        if ( !$have_mapping{$subscriber}->{$ip} ) {
            print "Setting mapping to $subscriber for ip $ip.\n";
            print $loadfh "add-mapping $subscriber $ip $lifetime\n";
        }
    }
}
print "Done.\n";

close($loadfh);
