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
require NetMaint::DNS;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Subnet Special Address Listing" );
$html->PageHeader();
$html->RequirePriv("netmgr-user");

my $log = new NetMaint::Logging;
my $net = new NetMaint::Network;
my $dns = new NetMaint::DNS;

$log->Log();

print "This report indicates allocation and DNS information for any subnet special addresses. Note, the label column\n";
print
    "indicates typical/standard usage for that position IP address, and is not always accurate for all subnet types.\n";
print "<p/>\n";

my $info = $net->GetSubnets();

$html->StartMailWrapper("Subnet Special Addresses");
$html->StartBlockTable( "Subnet Special Addresses", 1100 );
$html->StartInnerTable( "", "Addr", "Label", "Type", "Allocation", "DNS" );

foreach my $sn ( $net->NetworkSort( keys( %{$info} ) ) ) {
    my $vlan = $info->{$sn}->{vlan} || "none";
    my $name = $info->{$sn}->{description};
    my $tmpl = $info->{$sn}->{template} || "unknown";

    # Skip known "fake" subnets
    next if ( $sn =~ /^10\.0\./ );

    $html->StartInnerRow();
    print "<td colspan=7><b><a href=\"subnet-ip-alloc.pl?mode=report&subnet=", $html->Encode($sn),
        "\">$sn</a>: $name</b> - VLAN[$vlan]  Template[$tmpl]</td>\n";
    $html->EndInnerRow();

    my %addr  = $net->GetAddresses($sn);
    my @saddr = $net->NetworkSort( keys %addr );

    my @special = (
        [ $saddr[0],             "Network" ],
        [ $saddr[ $#saddr - 3 ], "Router 1" ],
        [ $saddr[ $#saddr - 2 ], "Router 2" ],
        [ $saddr[ $#saddr - 1 ], "Gateway" ],
        [ $saddr[$#saddr],       "Broadcast" ],
    );

    foreach my $aref (@special) {
        my ( $ip, $label, $notes ) = @{$aref};
        $html->StartInnerRowSame();
        print "<td width=20>&nbsp;</td>\n";

        my %ipinfo = $net->GetAddressDetail($ip);

        my @ptr;
        foreach my $rec ( $dns->Search_PTR_Records_IP_Exact($ip) ) {
            push( @ptr, $rec->{address} );
        }

        print "<td>$ip</td>\n";
        print "<td>$label</td>\n";
        print "<td>", $ipinfo{type}, "</td>\n";
        print "<td>", $ipinfo{host}, "</td>\n";

        print "<td>", join( ", ", @ptr ), "</td>\n";

        $html->EndInnerRowSame();
    }
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();
