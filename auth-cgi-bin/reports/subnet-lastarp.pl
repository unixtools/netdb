#!/usr/bin/perl

# Begin-Doc
# Name: subnet-lastarp.pl
# Type: script
# Description: Report on last arp by ip by subnet
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Logging;

use UMR::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $net  = new NetMaint::Network;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet Last ARP Report" );

if ( $mode eq "" ) {
    my $info = $net->GetSubnets();

    my @subnets = $net->NetworkSort( keys( %{$info} ) );

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Last ARP Report for Subnet:<p/>";
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
    my $arp    = new NetMaint::ARP;
    my $util   = new NetMaint::Util;
    my $dns    = new NetMaint::DNS;
    my $subnet = $rqpairs{subnet};
    my $days   = int( $rqpairs{days} );

    $html->StartMailWrapper("Last ARP Report for $subnet");
    $html->StartBlockTable("Last ARP Report for $subnet");
    $html->StartInnerTable( "IP", "Allocation", "Age", "Last Seen", "Ether", "Host" );

    my %addrs = $net->GetAddresses($subnet);
    my @addrs = $net->NetworkSort( keys(%addrs) );

    foreach my $ip (@addrs) {
        my %info = $arp->GetIPLastARP($ip);

        my @recs = $dns->Search_A_Records_Address_Exact($ip);

        next if ( !$info{ip} && $#recs < 0 );

        $html->StartInnerRow();

        print "<td>$ip</td>\n";
        print "<td>", $addrs{$ip}, "</td>\n";

        if ( $info{ip} ) {
            $info{tstamp} =~ s/\s.*//gio;
            print "<td><tt>", int( $info{age} ), "</td>\n";
            print "<td><tt>", $info{tstamp}, " on ", $info{router}, "</td>\n";
            print "<td><tt>", $html->SearchLink_Ether( $util->FormatEther( $info{ether} ) ), "</td>\n";
        }
        else {
            print "<td>&nbsp;</td>\n";
            print "<td>never</td>\n";
            print "<td>&nbsp;</td>\n";
        }

        print "<td><tt>";
        my @tmp = ();
        foreach my $rec (@recs) {
            push( @tmp, $html->SearchLink_Host( $rec->{name} ) );
        }
        print join( "<br/>", @tmp );
        print "&nbsp;";
        print "</td>\n";

        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();

}

$html->PageFooter();

