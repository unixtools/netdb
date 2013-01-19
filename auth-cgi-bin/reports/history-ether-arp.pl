#!/usr/bin/perl

# Begin-Doc
# Name: history-ether-arp.pl
# Type: script
# Description: report on arp history for an ethernet address
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Logging;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;

$html->PageHeader( title => "View ARP History for Ethernet Address" );

my $hosts = new NetMaint::Hosts;
my $dhcp  = new NetMaint::DHCP;
my $arp   = new NetMaint::ARP;
my $util  = new NetMaint::Util;
my $dns   = new NetMaint::DNS;
my $log   = new NetMaint::Logging;

my $search = $rqpairs{search};
my $mode   = $rqpairs{mode};

$log->Log();

if ( $mode eq "" ) {
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "ARP History Report for Ethernet Address:<p/>";
    &HTMLHidden( "mode", "report" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $ether = $util->CondenseEther($search);
    my $arphist = $arp->GetARPHistory( ether => $ether );

    $log->Log( ether => $ether );

    $html->StartMailWrapper("ARP History - $ether");

    $html->Display_ARP_History(
        title   => "ARP History - $ether",
        entries => $arphist
    );

    $html->EndMailWrapper();
}

$html->PageFooter();

