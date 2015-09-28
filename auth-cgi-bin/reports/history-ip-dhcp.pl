#!/usr/bin/perl

# Begin-Doc
# Name: history-ip-dhcp.pl
# Type: script
# Description: Report on dhcp history for an ip
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Logging;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;

$html->PageHeader( title => "View DHCP History for IP" );

my $hosts = new NetMaint::Hosts;
my $dhcp  = new NetMaint::DHCP;
my $util  = new NetMaint::Util;
my $dns   = new NetMaint::DNS;
my $log   = new NetMaint::Logging;

my $search = $rqpairs{search};
my $mode   = $rqpairs{mode};

$log->Log();

if ( $mode eq "" ) {
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "DHCP History Report for IP:<p/>";
    &HTMLHidden( "mode", "report" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $ip = $util->CondenseIP($search);

    $log->Log( address => $ip );

    $html->StartMailWrapper("DHCP History - $ip");

    my $dhcphist = $dhcp->GetDHCPHistory( ip => $ip );

    $html->Display_DHCP_History(
        title   => "DHCP History - $ip",
        entries => $dhcphist
    );

    $html->EndMailWrapper();
}

$html->PageFooter();

