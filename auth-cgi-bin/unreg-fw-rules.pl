#!/usr/bin/perl

# Begin-Doc
# Name: unreg-fw-rules.pl
# Type: script
# Description: output firewall rules script for unreg ranges
# End-Doc

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

use strict;

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Logging;
require NetMaint::Network;

use Local::PrivSys;
use NetAddr::IP;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Unregistered Host Firewall Rules" );

$html->PageHeader();
$html->RequirePriv("sysprog:netdb:alloc");

my $util = new NetMaint::Util;
my $net  = new NetMaint::Network;

$html->StartMailWrapper("Unregistered Host Firewall Rules");
print "<div align=left><pre>\n";

print <<EOCONF;
! global access to allow all systems to minimal services
! DO NOT CHANGE WITHOUT UPDATING NETDB!
! This output assumes functionality provided by aclmgr
! web-dweb-vip
permit ip any host %IP(web-dweb-vip.srv.mst.edu)%
! itapps-itweb-vip
permit ip any host %IP(itapps-itweb-vip.srv.mst.edu)%
! netreg
permit ip any host %IP(netreg.srv.mst.edu)%
! docweb-vip
permit ip any host %IP(docweb-vip.srv.mst.edu)%
! dhcp srvers
permit ip any 131.151.248.64/28
EOCONF

print "\n";
print "! begin unregistered subnet restrictions\n";

my @nips    = ();
my $subnets = $net->GetSubnets();
foreach my $sn ( keys(%$subnets) ) {
    my @addresses = $net->NetworkSort( $net->GetAllocatedAddresses( $sn, "unreg" ) );

    foreach my $ip (@addresses) {
        push( @nips, NetAddr::IP->new($ip) );
    }
}

my $nip    = $nips[0];
my @ranges = $nip->compact(@nips);
foreach my $range (@ranges) {
    if ( $range =~ m|(.*)/32|o ) {
        print "deny ip host $1 any\n";
    }
    else {
        print "deny ip $range any\n";
    }
}
print "! end of dynamic unregistered ranges\n";
print "</pre>\n";
print "</div>\n";
$html->EndMailWrapper();
$html->PageFooter();

