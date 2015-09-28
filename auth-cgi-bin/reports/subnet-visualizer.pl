#!/usr/bin/perl

# Begin-Doc
# Name: subnet-visualizer.pl
# Type: script
# Description: list of subnets in visual form showing free blocks/etc.
# End-Doc

use strict;

use NetAddr::IP;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;
use Local::PrivSys;

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Logging;

&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet Visualizer" );

print "<a href=\"?showall=on\">Show All Subnets</a> | ";
print "<a href=\"?showall=off\">Show Server Subnets</a><p>";

&HTMLStartForm( &HTMLScriptURL(), "GET" );

my $net = new NetMaint::Network;

my $subnets = $net->GetSubnets();

my %active_subnets = ();
SN: foreach my $sn ( keys(%$subnets) ) {
    my ( $ip, $bits ) = split( '/', $sn );

    foreach my $tbits ( reverse( 16 .. $bits ) ) {
        my $tmp   = new NetAddr::IP "$ip/$tbits";
        my $range = $tmp->range();
        $range =~ s/\s*\-.*//go;

        my $newsn = "$range/$tbits";

        #next SN if ( $active_subnets{$newsn} );

        $active_subnets{$newsn} = 1;
    }

}

# Init tree
my $tree = {};

# Generate list of base/starting subnets at top level of tree
my %bases = ();
$bases{"128.206.230.0/23"} = 1;
$bases{"131.151.0.0/16"}   = 1;
if ( $rqpairs{showall} eq "on" ) {
    $bases{"192.55.114.0/24"}  = 1;
    $bases{"192.65.97.0/24"}   = 1;
    $bases{"207.160.128.0/24"} = 1;
    foreach my $sn ( keys(%$subnets) ) {
        if ( $sn =~ /^(10\.\d+)\./ ) {
            $bases{ $1 . ".0.0/16" } = 1;
        }
    }
    $bases{"172.16.0.0/16"}    = 1;
    $bases{"172.17.0.0/16"}    = 1;
    $bases{"192.168.5.0/24"}   = 1;
    $bases{"192.168.10.0/24"}  = 1;
    $bases{"192.168.254.0/24"} = 1;
}

# Load tree starting point
foreach my $base ( keys %bases ) {
    $tree->{children}->{$base} = {};
}

&GenTree( $tree, "TOP" );

print "<style type=\"text/css\">\n";
print <<EOCSS;
.sntree{
  width:100%;
  border-style:solid;
  border-width:1px;
  background-color:#ddeeee;
}
.sntree_active{
  width:100%;
  border-style:solid;
  border-width:1px;
  background-color:#cc9999;
}
.sntree_open{
  width:100%;
  border-style:solid;
  border-width:1px;
  background-color:#ccffcc;
}
EOCSS
print "</style>\n";

$html->StartBlockTable( "Subnets", 1000 );
DumpTree_A($tree);
$html->EndBlockTable();

sub DumpTree_A {
    my $node = shift;
    my $name = shift;

    my @children = $net->NetworkSort( keys %{ $node->{children} } );

    if ( $node->{status} eq "active" ) {
        print "<table class=sntree_active>";
    }
    elsif ( scalar(@children) == 0 ) {
        print "<table class=sntree_open>";
    }
    else {
        print "<table class=sntree>";
    }

    if ($name) {
        print "<tr><td colspan=2><tt>";

        if ( $subnets->{$name} ) {
            print "<a href=\"subnet-ip-alloc.pl?mode=report&subnet=$name\">$name</a>: ";
        }
        else {
            print "$name: ";
        }

        my $nip = new NetAddr::IP $name;
        print " ", $nip->range(), "</tt>";

        my $label = $subnets->{$name}->{description};
        if ( $subnets->{$name}->{vlan} ) {
            $label .= " [VLAN " . $subnets->{$name}->{vlan} . "]";
        }
        if ($label) {
            print " - $label";
        }

        print "</td></tr>\n";
    }
    foreach my $child (@children) {
        print "<tr><td>&nbsp;</td><td>";
        &DumpTree_A( $node->{children}->{$child}, $child );
        print "</td></tr>\n";
    }
    print "</table>\n";
}

$html->PageFooter();

# Begin-Doc
# Name: GenTree
# Description: Builds subnodes of the subnet tree based on whether the children are active or not
# Syntax: &GetTree($node,$name,[$depth]);
# End-Doc
sub GenTree {
    my $node  = shift;
    my $name  = shift;
    my $depth = int(shift);
    my $pad   = " " x $depth;

    if ( $subnets->{$name} ) {
        $node->{status} = "active";
    }

    # Populate any children that don't already exist
    my ( $net, $bits ) = split( '/', $name );
    if (   $net
        && $bits >= 16
        && $bits < 30
        && $active_subnets{$name}
        && !$subnets->{$name} )
    {
        my $newbits = $bits + 1;
        my $nip     = new NetAddr::IP $name;
        my @tmp     = $nip->split($newbits);
        foreach my $cnip (@tmp) {
            my $childnet = $cnip . "";

            if ( !$node->{children}->{$childnet} ) {
                $node->{children}->{$childnet} = {};
            }
            if ( $subnets->{$childnet} ) {
                $node->{children}->{$childnet}->{status} = "active";
            }

        }
    }

    foreach my $child ( keys( %{ $node->{children} } ) ) {
        &GenTree( $node->{children}->{$child}, $child, $depth + 1 );
    }
}
