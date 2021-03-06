#!/usr/bin/perl

# Begin-Doc
# Name: subnet-ip-alloc.pl
# Type: script
# Description: Report on ip allocation by subnet
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::DNS;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("netmgr-user");

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

    print "<b>Note: Italicized hostnames are dynamic registrations</b><p>\n";

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

        my @hosts = ();
        if ( $info{host} ) {
            push( @hosts, $html->SearchLink_Host( $info{host} ) );
        }
        my @dns = $dns->Search_A_Records_Address_Exact($ip);
        foreach my $rec (@dns) {
            next if ( $rec->{name} eq $info{host} );
            push( @hosts, "<i>" . $html->SearchLink_Host( $rec->{name} ) . "</i>" );
        }

        if ( scalar(@hosts) > 0 ) {
            print "<td>", join( ", ", @hosts ), "</td>\n";
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

