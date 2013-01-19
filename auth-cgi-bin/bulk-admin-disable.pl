#!/usr/bin/perl

# Begin-Doc
# Name: bulk-admin-disable.pl
# Type: script
# Description: admin disable a batch of hosts at once
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::PrivSys;
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::Access;
use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $mode   = $rqpairs{"mode"};
my $search = $rqpairs{"search"};
$search =~ s/^\s+//gio;
$search =~ s/\s+$//gio;

my $html   = new NetMaint::HTML( title => "Bulk Admin Disable" );
my $dns    = new NetMaint::DNS;
my $hosts  = new NetMaint::Hosts;
my $dhcp   = new NetMaint::DHCP;
my $util   = new NetMaint::Util;
my $arp    = new NetMaint::ARP;
my $access = new NetMaint::Access;

$html->PageHeader();

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs("public") );
if ( !$privs{"sysprog:netdb:search"} && !$privs{"sysprog:netdb"} ) {
    $html->ErrorExit("Access Denied.");
}

if ( !$privs{"sysprog:netdb:adminlock"} ) {
    $html->ErrorExit("Permission Denied.");
}

if ( $mode eq "" ) {
    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by IP Address:<br/>\n";
    print "List multiple whitespace separated IP addresses to search on.<br/>\n";
    &HTMLHidden( "mode", "search" );
    &HTMLTextArea( "addresses", $rqpairs{addresses}, 40, 15, "BOTH" );
    print "<p/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";

}
elsif ( $mode eq "search" ) {
    $dns = new NetMaint::DNS;
    my $net = new NetMaint::Network;

    my $addr     = $rqpairs{addresses};
    my @searches = ();
    while ( $addr =~ m|(\d+\.\d+\.\d+\.\d+)|go ) {
        push( @searches, $1 );
    }
    foreach my $search ( split( /\s+/, $addr ) ) {
        push( @searches, $search );
    }

    print "Search: ", join( ", ", @searches ), "<p/>\n";

    #
    # First search all hard registered owners of these IP addresses
    #
    my %list = ();
    foreach my $search (@searches) {
        my @recs = $dns->Search_A_Records_Address_Exact( $search, 1000 );
        my @recs2 = $hosts->SearchByName( $search, 50 );
        my @recs3 = $hosts->SearchByOwnerExact( $search, 50 );
        my %alloc_info = $net->GetAddressDetail($search);

        my %seen = ();
        foreach my $rec (@recs) {
            my $host = $rec->{name};

            next if ( $host =~ /^dyn-.*/o );
            next if ( $seen{$host} );
            $list{$search}->{$host}->{"dns-ip"} = 1;
        }

        foreach my $host (@recs2) {
            next if ( $host =~ /^dyn-.*/o );
            next if ( $seen{$host} );
            $list{$search}->{$host}->{"name"} = 1;
        }

        foreach my $host (@recs3) {
            next if ( $host =~ /^dyn-.*/o );
            next if ( $seen{$host} );
            $list{$search}->{$host}->{"owner"} = 1;
        }

        if ( $alloc_info{host} ) {
            my $host = $alloc_info{host};
            $list{$search}->{$host}->{"allocation"} = 1;
        }

        #
        # Add in stuff to look over last arp...
        #
        my %arp = $arp->GetIPLastARP($search);
        if ( $arp{ether} ) {
            my $host = $dhcp->SearchByEtherExact( $arp{ether} );
            $list{$search}->{$host}->{"arp"} = 1;
        }
    }

    my @list;
    foreach my $ip ( sort( keys(%list) ) ) {
        foreach my $host ( sort( keys( %{ $list{$ip} } ) ) ) {
            my $reasons = join( ", ", sort( keys( %{ $list{$ip}->{$host} } ) ) );
            push( @list, [ $host, "$ip: $host [$reasons]" ] );
        }
    }

    if ( scalar(@list) < 0 ) {
        print "<h3>No matches found searching for '<tt>${addr}</tt>'.</h3>\n";
    }
    else {
        &HTMLStartForm( &HTMLScriptURL(), "GET" );
        &HTMLHidden( "mode", "disable" );

        print "Matching hosts:<br/>\n";
        &HTMLStartSelect( "hosts", 10, 1 );
        my $cnt = 0;
        foreach my $row (@list) {
            my ( $host, $label ) = @{$row};
            print "<option value=\"$host\">$label\n";
            $cnt++;
        }
        if ( $cnt >= 999 ) {
            print "<option value=\"\"> - list may be incomplete, max records reached -\n";
        }
        &HTMLEndSelect();
        print "<p/>\n";

        print "Admin Message: ";
        &HTMLInputText( "message", 60, $rqpairs{message} );

        print "<p/>\n";
        &HTMLSubmit("Disable Hosts");
        &HTMLEndForm();
    }
}
elsif ( $mode eq "disable" ) {
    my $blockhosts = $rqpairs{hosts};
    my @blockhosts = split( ' ', $blockhosts );
    my $message    = $rqpairs{message};

    my %blockhosts = ();
    foreach my $host (@blockhosts) {
        $blockhosts{$host} = 1;
    }

    foreach my $host ( sort( keys(%blockhosts) ) ) {
        print "Blocking host '", $html->Encode($host), "' with message '$message'.<p/>\n";
        $hosts->SetAdminLock($host);
        $hosts->SetAdminComments( $host, $message );
        $dhcp->AddAdminOption( $host, "DISABLE" );

        my $info = $hosts->GetHostInfo($host);
        $hosts->SendAdminDisableNotice($host);

        print "<h3>System disabled email sent to '", $info->{owner}, "'.</h3><p/>\n";

    }
}

$html->PageFooter();
