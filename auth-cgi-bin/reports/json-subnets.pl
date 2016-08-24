#!/usr/bin/perl

# Begin-Doc
# Name: json-subnets.pl
# Type: script
# Description: return list of subnets in json form
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Logging;

use JSON;

use Local::PrivSys;
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType("application/json");

my $log = new NetMaint::Logging;
$log->Log();

my $net = new NetMaint::Network;

my $info  = $net->GetSubnets();
my $vlans = $net->GetVLANs();

my $filter      = $rqpairs{filter};
my $filterexact = $rqpairs{filterexact};

my $which = "All";
if ($filter) {
    $which = $filter;
}
elsif ($filterexact) {
    $which = $filterexact;
}

my %res;
foreach my $sn ( $net->NetworkSort( keys( %{$info} ) ) ) {
    my $vlan      = $info->{$sn}->{vlan};
    my $vlan_name = $vlans->{$vlan}->{name};

    next
        if ( $filterexact
        && index( $info->{$sn}->{description}, $filterexact ) < 0 );
    next
        if ( $filter
        && index( lc( $info->{$sn}->{description} ), lc($filter) ) < 0 );

    my $rec = {
        name            => $sn,
        link_alloc_view => "<a href=\"subnet-ip-alloc.pl?mode=report&subnet=$sn\">View</a>",
        vlan            => "-",
        template        => $info->{$sn}->{template},
        mask            => $info->{$sn}->{mask},
        gateway         => $info->{$sn}->{gateway},
        description     => $info->{$sn}->{description},
    };

    if ($vlan) {
        $rec->{vlan} = "$vlan: $vlan_name";
    }

    push( @{ $res{data} }, $rec );
}

my $json = new JSON;
print $json->pretty->canonical->encode( \%res );
