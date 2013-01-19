#!/usr/bin/perl

# Begin-Doc
# Name: ajax-subnets.pl
# Type: script
# Description: simple callback script to return a list of subnets by searching name and/or description
# End-Doc

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use JSON;
use UMR::OracleObject;

use lib "/local/netdb/libs";
use NetMaint::Network;

use strict;

&HTMLGetRequest();
&HTMLContentType("application/json");

my $q   = $rqpairs{q};
my $max = int( $rqpairs{max} );
if ( $max < 1 || $max > 250 ) {
    $max = 30;
}

my $net  = new NetMaint::Network;
my $info = $net->GetSubnets();

my @matches;
my $id = 0;
foreach my $sn ( $net->NetworkSort( keys %$info ) ) {
    my $txt = $sn . ": " . $info->{$sn}->{description} . " [" . $info->{$sn}->{vlan} . "]";

    if ( index( lc($txt), lc($q) ) >= 0 ) {
        $id++;
        push( @matches, { id => $id, value => $txt, info => "" } );
        last if ( $id > $max );
    }
}

print to_json( { results => \@matches } );

