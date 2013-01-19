#!/usr/bin/perl

# Begin-Doc
# Name: subnet-expireip.pl
# Type: script
# Description: Report on host expiration by subnet
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::ARP;
require NetMaint::DNS;
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

$html->PageHeader( title => "Subnet Host Expiration Report" );

if ( $mode eq "" ) {
    my $info = $net->GetSubnets();

    my @subnets = $net->NetworkSort( keys( %{$info} ) );

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Host Expiration Report for Subnet:<p/>";
    &HTMLHidden( "mode", "report" );
    &HTMLStartSelect( "subnet", 1 );
    print "<option value=\"\">\n";
    foreach my $sn (@subnets) {
        print "<option value=\"$sn\">$sn - " . $info->{$sn}->{description} . "\n";
    }
    &HTMLEndSelect();
    print "<p/>\n";
    print "Minimum Age to Expire: ";
    &HTMLInputText( "days", 10, 18 * 30 ), " days.<br/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $arp    = new NetMaint::ARP;
    my $util   = new NetMaint::Util;
    my $dns    = new NetMaint::DNS;
    my $subnet = $rqpairs{subnet};
    my $days   = int( $rqpairs{days} );

    $html->StartMailWrapper("Subnet Host Expiration $subnet ($days days)");
    $html->StartBlockTable("Subnet Host Expiration $subnet ($days days)");
    $html->StartInnerTable( "IP", "Allocation", "Age", "Last Seen", "Ether", "Host", "Options" );

    my %addrs = $net->GetAddresses($subnet);
    my @addrs = $net->NetworkSort( keys(%addrs) );

    foreach my $ip (@addrs) {
        my %info = $arp->GetIPLastARP($ip);
        next if ( $info{ip} && ( int( $info{age} ) < $days ) );

        my @recs = $dns->Search_A_Records_Address_Exact($ip);
        next if ( $#recs < 0 );

        $html->StartInnerRow();
        print "<td>$ip</td>\n";
        print "<td>", $addrs{$ip}, "</td>\n";

        if ( $info{ip} ) {
            $info{tstamp} =~ s/\s.*//gio;
            print "<td>", int( $info{age} ), "</td>\n";
            print "<td>", $info{tstamp}, " on ", $info{router}, "</td>\n";
            print "<td>", $html->SearchLink_Ether( $util->FormatEther( $info{ether} ) ), "</td>\n";
        }
        else {
            print "<td>&nbsp;</td>\n";
            print "<td>never</td>\n";
            print "<td>&nbsp;</td>\n";
        }

        my @tmp_hosts = ();
        my @tmp_opts  = ();
        foreach my $rec (@recs) {
            push( @tmp_hosts, $html->SearchLink_Host( $rec->{name} ) );
            push( @tmp_opts,
                      "<a target=_deletehost href=\"/auth-cgi-bin/cgiwrap/netdb/edit-host.pl?mode=deletehost&host="
                    . $rec->{name}
                    . "\">Delete Host</a>" );
        }
        print "<td>";
        print join( "<br/>", @tmp_hosts );
        print "&nbsp;";
        print "</td>\n";

        print "<td>";
        print join( "<br/>", @tmp_opts );
        print "&nbsp;";
        print "</td>\n";

        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

