#!/usr/bin/perl

# Begin-Doc
# Name: subnet-freeip.pl
# Type: script
# Description: Report on free ip addresses by subnet
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $net  = new NetMaint::Network;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet Free IP Addresses Report" );

if ( $mode eq "" ) {
    my $info = $net->GetSubnets();

    my @subnets = $net->NetworkSort( keys( %{$info} ) );

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Free IP Report for Subnet:<p/>";
    &HTMLHidden( "mode", "report" );
    &HTMLStartSelect( "subnet", 1 );
    print "<option value=\"\">\n";
    foreach my $sn (@subnets) {
        print "<option value=\"$sn\">$sn - " . $info->{$sn}->{description} . "\n";
    }
    &HTMLEndSelect();
    print "<p/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $subnet = $rqpairs{subnet};

    $html->StartMailWrapper("Free Addresses on $subnet");
    $html->StartBlockTable("Free Addresses on $subnet");
    $html->StartInnerTable( "IP Address", "Type" );

    my $info = $net->GetAddressesDetail($subnet);

    my @addrs = $net->NetworkSort( $net->GetFreeAddresses($subnet) );
    foreach my $addr (@addrs) {
        my $type = $info->{$addr}->{type};

        $html->StartInnerRow();
        print "<td>$addr</td>\n";
        print "<td>$type</td>\n";
        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

