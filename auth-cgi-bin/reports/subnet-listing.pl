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
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet Listing" );

&HTMLStartForm( &HTMLScriptURL(), "GET" );

print "This report indicates the currently defined subnets on the network.\n";
print "<p/>\n";
print "<a href=\"?\">Show all networks</a> | ";
print "Filter: ";
&HTMLInputText( "filter", 15, $html->Encode( $rqpairs{filter} ) );
print " ";
&HTMLSubmit("Filter");
&HTMLEndForm();
print "<br>\n";
print "<a href=\"?filterexact=SRV\">Show server networks</a> | ";
print "<a href=\"?filterexact=TEST\">Show test networks</a>\n";

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

$html->StartMailWrapper("Currently Defined Subnets ($which)");

$html->StartBlockTable( "Currently Defined Subnets ($which)", 1000 );

print "<table border=0 class=\"display cell-border compact\" id=\"subnets\">\n";

print "<thead><tr><th>Subnet</th><th>Action</th><th>VLAN</th><th>Template</th><th>Netmask</th>";
print "<th>Gateway</th><th>Desc</th></tr></thead>\n";
print "<tbody>\n";

foreach my $sn ( $net->NetworkSort( keys( %{$info} ) ) ) {
    my $vlan      = $info->{$sn}->{vlan};
    my $vlan_name = $vlans->{$vlan}->{name};

    next
        if ( $filterexact
        && index( $info->{$sn}->{description}, $filterexact ) < 0 );
    next
        if ( $filter
        && index( lc( $info->{$sn}->{description} ), lc($filter) ) < 0 );

    print "<tr>\n";
    print "<td class=sn_mono>$sn</td>\n";
    print "<td><a href=\"subnet-ip-alloc.pl?mode=report&subnet=$sn\">View</a></td>\n";
    if ( !$vlan ) {
        print "<td class=sn_mono>&nbsp;</td>\n";
    }
    else {
        print "<td class=sn_mono>$vlan: $vlan_name</td>\n";
    }
    print "<td class=sn_mono>", $info->{$sn}->{template},    "</td>\n";
    print "<td class=sn_mono>", $info->{$sn}->{mask},        "</td>\n";
    print "<td class=sn_mono>", $info->{$sn}->{gateway},     "</td>\n";
    print "<td>",     $info->{$sn}->{description}, "</td>\n";
    print "</tr>\n";
}

print "</tbody>\n";
print "</table>\n";
$html->EndBlockTable();

print <<EOJS;
<script type="text/javascript">
   \$('#subnets').DataTable( {
        "deferRender" : true,
        "processing": true,
        "paging": false
    });
</script>
EOJS

$html->EndMailWrapper();

$html->PageFooter();
