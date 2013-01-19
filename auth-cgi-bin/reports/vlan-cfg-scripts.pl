#!/usr/bin/perl

# Begin-Doc
# Name: subnet-listing.pl
# Type: script
# Description: list of subnets
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet Listing" );

my $net = new NetMaint::Network;

my $mode = $rqpairs{mode};

print
    "This report generates a config script for defining vlans/updating vlan names on certain device types. Choose device type from the list below.\n";
print "<p/>\n";

my @links = ();
push( @links, "<a href=\"?mode=bigip\">F5 BigIp VLANs</a>" );
push( @links, "<a href=\"?mode=cisco\">Cisco Server VLANs</a>" );

print join( " - ", @links );
print "<p/><hr/>\n";

if ( $mode eq "cisco" ) {
    $html->StartBlockTable( "Cisco Server VLAN Config", 1000 );
    print "<pre>\n";

    $html->StartMailWrapper("Cisco Server VLAN Config");

    my $vlans = $net->GetVLANs();
    foreach my $vlan ( sort { $a <=> $b } keys %$vlans ) {
        my $name = $vlans->{$vlan}->{name};
        next if ( $name !~ /^SRV/ );

        next if ( int($vlan) ne $vlan );

        print "vlan $vlan\n";
        print "  name $name\n";
    }
    $html->EndMailWrapper();

    print "</pre>\n";
    $html->EndBlockTable();
}
elsif ( $mode eq "bigip" ) {
    $html->StartBlockTable( "F5 BigIP VLAN Config", 1000 );
    print "<pre>\n";

    $html->StartMailWrapper("F5 BigIP VLAN Config");

    my $vlans = $net->GetVLANs();
    foreach my $vlan ( sort { $a <=> $b } keys %$vlans ) {
        my $name = $vlans->{$vlan}->{name};
        next if ( $name !~ /^SRV/ );

        next if ( int($vlan) ne $vlan );

        my $oct1 = int( $vlan >> 8 );
        my $oct2 = $vlan % 256;
        my $ext  = sprintf( "%.2x:%.2x", $oct1, $oct2 );

        print <<EOM;
vlan VLAN$vlan {
   tag $vlan
   mac masq 02:01:D7:99:$ext
   trunks tagged ServiceTrunk
}

EOM

    }
    $html->EndMailWrapper();

    print "</pre>\n";
    $html->EndBlockTable();
}

$html->PageFooter();
