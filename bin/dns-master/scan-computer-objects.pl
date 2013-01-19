#!/usr/bin/perl

# Begin-Doc
# Name: scan-computer-objects.pl
# Description: scan and mark/purge ADS computer objects based on netdb status
# End-Doc

use lib "/local/umrperl/libs";
use UMR::OracleObject;
use UMR::SysProg::SetUID;
use UMR::SysProg::ADSObject;

use lib "/local/netdb/libs";
use NetMaint::DB;

use strict;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";

my $qry = "select host from hosts";
my $cid = $db->SQL_OpenQuery($qry) || die;

my %have_short;
my %short_to_long;
my %have_long;

print "Scanning netdb host list.\n";
while ( my ($hostname) = $db->SQL_FetchRow($cid) ) {
    my $short = $hostname;
    $short =~ s/\..*//go;

    $have_short{$short}    = 1;
    $short_to_long{$short} = $hostname;
    $have_long{$hostname}  = 1;
}
print "Done.\n\n";

my $ad_gc = new UMR::SysProg::ADSObject( use_gc => 1 ) || die;

my @paths = (
    [ "mst.edu", "mst-dc.mst.edu", "DC=mst,DC=edu", "OU=Workstations,DC=mst,DC=edu", "purge" ],
    [ "mst.edu", "mst-dc.mst.edu", "DC=mst,DC=edu", "OU=Servers,DC=mst,DC=edu",      "mark" ],
    [ "mst.edu", "mst-dc.mst.edu", "DC=mst,DC=edu", "CN=Computers,DC=mst,DC=edu",    "purge" ],
);

my $dryrun = 0;

my $lastdom = "";
my $ad;
foreach my $pathref (@paths) {
    my ( $dom, $server, $base, $ou, $action ) = @{$pathref};

    if ( $dom ne $lastdom ) {
        print "\n";
        print "Connecting to $server with base $base.\n";
        print "\n";
        $ad = new UMR::SysProg::ADSObject(
            domain => "mst.edu",
            server => $server,
            basedn => $base
        ) || die $UMR::SysProg::ADSObject::ErrorMsg;
        $lastdom = $dom;
    }

    print "Scanning $ou:\n";

    my $info = $ad->GetAttributesMatch(
        "(&(objectClass=computer)(dNSHostName=*))",
        base       => $ou,
        attributes => [ qw(distinguishedName dNSHostName sAMAccountName description extensionAttribute15) ],
        maxrecords => 0,
    );

    foreach my $obj ( @{$info} ) {
        my ($dn) = @{ $obj->{distinguishedName} };

        my ($hn) = @{ $obj->{dNSHostName} };
        my ($sa) = @{ $obj->{sAMAccountName} };
        my $desc;
        if ( $obj && ref( $obj->{description} ) eq "ARRAY" ) {
            ($desc) = @{ $obj->{description} };
        }
        my $ea;
        if ( $obj && ref( $obj->{extensionAttribute15} ) eq "ARRAY" ) {
            ($ea) = @{ $obj->{extensionAttribute15} };
        }

        $hn = lc $hn;

        my $origsa = $sa;
        $sa =~ s/\$$//;
        $sa = lc $sa;

        if ( $dn =~ /.*-VDI,OU=Windows,OU=Workstations/o ) {

            # Skip this one
            next;
        }

        if ( $dn =~ /OU=VDI,OU=Windows,OU=Workstations/o ) {

            # Skip this one
            next;
        }

        my ( $mark_stamp, $mark_time );
        if ( $ea =~ /^NetDB Purge Mark: (\d+)/ ) {
            $mark_stamp = $1;
            $mark_time  = scalar( localtime($mark_stamp) );
        }

        my $cutoff          = 3;
        my $in_computers_ou = 0;
        if ( $dn =~ /CN=Computers,DC=mst,DC=edu$/ ) {
            $in_computers_ou = 1;
            $cutoff          = 7;
        }

        my ( $miss_long, $miss_short );
        if ( ( !$have_long{$hn} && !$have_short{$sa} ) || $in_computers_ou ) {
            my $reason = "not found in netdb";
            if ($in_computers_ou) {
                $reason = "found in prohibited computers OU";
            }
            print " $hn ($origsa) $reason.\n";
            print "  DN: $dn\n";
            print "  $hn / $sa / $ea.\n";

            if ( $mark_stamp && $mark_stamp < time - $cutoff * 24 * 60 * 60 ) {
                print "  Host was marked over $cutoff days ago ($mark_time), immediate action: $action.\n";

                if ( $action eq "purge" ) {

                    print "  Purging host $origsa  ($dn)\n";
                    my $ldap = $ad->{ldap};

                    # Ignore any error on this one, it's a contained object that only some hosts seem to have
                    unless ($dryrun) {
                        my $res = $ldap->delete( "CN=RouterIdentity," . $dn );

                        my $ldapres = $ldap->delete($dn);
                        if ( $ldapres->code ) {
                            print "  ERROR: ", $ldapres->error, "\n";
                        }
                    }
                }
                else {
                    unless ($dryrun) {
                        my $res = $ad->SetAttributes(
                            userid     => $origsa,
                            attributes => [ description => "WARNING - object immediate action: $action" ],
                        );
                        if ($res) {
                            print "  ERROR: $res\n";
                        }
                    }
                }
            }
            elsif ($mark_stamp) {
                print "  Host already marked ($mark_time), but in holding period.\n";

                my $remaining = ( $mark_stamp - ( time - $cutoff * 24 * 60 * 60 ) ) / ( 24 * 60 * 60 );
                my $rem_str = sprintf( "%.1f days", $remaining );

                unless ($dryrun) {
                    my $res = $ad->SetAttributes(
                        userid     => $origsa,
                        attributes => [ description => "WARNING - object will be removed in $rem_str - $reason" ],
                    );
                    if ($res) {
                        print "  ERROR: $res\n";
                    }
                }
            }
            else {
                my $mark_stamp = time;
                print "  Host not yet marked. Adding mark to host.\n";

                unless ($dryrun) {
                    my $res = $ad->SetAttributes(
                        userid     => $origsa,
                        attributes => [
                            extensionAttribute15 => "NetDB Purge Mark: $mark_stamp",
                            description          => "WARNING - object will be removed in $cutoff days - $reason",
                        ],
                    );
                    if ($res) {
                        print "  ERROR: $res\n";
                    }
                }
            }
        }
        else {
            if ($mark_stamp) {
                print " $hn ($origsa) found in netdb, but is marked for purge as of ($mark_time)\n";
                print "  Clearing mark.\n";

                unless ($dryrun) {
                    my $res = $ad->SetAttributes(
                        userid     => $origsa,
                        attributes => [
                            description          => " ",
                            extensionAttribute15 => " ",
                        ],
                    );
                    if ($res) {
                        print "  ERROR: $res\n";
                    }
                }
            }
        }
    }
    print "\n";
}
