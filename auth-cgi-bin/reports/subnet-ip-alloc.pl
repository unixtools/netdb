#!/usr/bin/perl

# Begin-Doc
# Name: subnet-ip-alloc.pl
# Type: script
# Description: Report on ip allocation by subnet
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::DNS;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("netdb-user");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $net  = new NetMaint::Network;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet IP Allocation Report" );

if ( $mode eq "" ) {
    my $info = $net->GetSubnets();

    my @subnets = $net->NetworkSort( keys( %{$info} ) );

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "IP Allocation Report for Subnet:<p/>";
    &HTMLHidden( "mode", "report" );
    &HTMLStartSelect( "subnet", 1 );
    print "<option value=\"\">\n";
    foreach my $sn (@subnets) {
        print "<option value=\"$sn\">$sn - " . $info->{$sn}->{description} . "\n";
    }
    &HTMLEndSelect();
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $util   = new NetMaint::Util;
    my $dns    = new NetMaint::DNS;
    my $subnet = $rqpairs{subnet};

    $html->StartMailWrapper("Subnet IP Allocation $subnet");
    $html->StartBlockTable("Subnet IP Allocation $subnet");
    $html->StartInnerTable( "IP", "Allocation", "Host" );

    my %addrs = $net->GetAddresses($subnet);
    my @addrs = $net->NetworkSort( keys(%addrs) );

    foreach my $ip (@addrs) {
        my %info = $net->GetAddressDetail($ip);

        $html->StartInnerRow();
        print "<td>$ip</td>\n";
        print "<td>", $info{type}, "</td>\n";

        if ( $info{host} ) {
            print "<td>", $html->SearchLink_Host( $info{host} ), "</td>\n";
        }
        else {
            print "<td>&nbsp;</td>\n";
        }

        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

