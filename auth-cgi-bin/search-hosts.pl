#!/usr/bin/perl

# Begin-Doc
# Name: search-hosts.pl
# Type: script
# Description: search hosts by various criteria
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::PrivSys;
use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Network;
use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $mode   = $rqpairs{"mode"};
my $search = $rqpairs{"search"};
$search =~ s/^\s+//gio;
$search =~ s/\s+$//gio;

my $html  = new NetMaint::HTML( title => "Search Hosts" );
my $dns   = new NetMaint::DNS;
my $hosts = new NetMaint::Hosts;
my $dhcp  = new NetMaint::DHCP;
my $util  = new NetMaint::Util;

$html->PageHeader();

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs("public") );
if ( !$privs{"netmgr-admin"} && !$privs{"netmgr-user"} ) {
    $html->ErrorExit("Permission Denied.");
}

if ( $mode eq "" ) {
    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Host Name:\n";
    &HTMLHidden( "mode", "byname" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Location:\n";
    &HTMLHidden( "mode", "byloc" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Description:\n";
    &HTMLHidden( "mode", "bydesc" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Domain: ";
    &HTMLHidden( "mode", "bydomainexact" );
    &HTMLStartSelect( "search", 1 );
    my %dom = $dns->GetDomains();
    print "<option value=\"\">\n";
    foreach my $dom ( sort( keys(%dom) ) ) {
        my $label = "$dom - " . $dom{$dom};
        print "<option value=\"$dom\">$label\n";
    }
    &HTMLEndSelect();
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Registered IP Address:\n";
    &HTMLHidden( "mode", "byip" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Owner UserID:\n";
    &HTMLHidden( "mode", "byowner" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Search by Ethernet Address:\n";
    &HTMLHidden( "mode", "byether" );
    &HTMLInputText( "search", 30 );
    &HTMLSubmit("Search");
    &HTMLEndForm();

}
elsif ( $mode eq "byname" ) {
    my $hosts = new NetMaint::Hosts;
    my @hosts = $hosts->SearchByName( $search, 1000 );

    my @list;
    foreach my $host ( sort @hosts ) {
        push( @list, [ $host, $host ] );
    }

    &PrintViewList(@list);
}
elsif ( $mode eq "byloc" ) {
    my $hosts = new NetMaint::Hosts;
    my @hosts = $hosts->SearchByLocation( $search, 1000 );

    my @list;
    foreach my $host ( sort @hosts ) {
        push( @list, [ $host, $host ] );
    }

    &PrintViewList(@list);
}
elsif ( $mode eq "bydesc" ) {
    my $hosts = new NetMaint::Hosts;
    my @hosts = $hosts->SearchByDescription( $search, 1000 );

    my @list;
    foreach my $host ( sort @hosts ) {
        push( @list, [ $host, $host ] );
    }

    &PrintViewList(@list);
}
elsif ( $mode eq "byowner" ) {
    my $hosts = new NetMaint::Hosts;
    my %hosts = $hosts->SearchByOwner( $search, 1000 );

    my @list;
    foreach my $host ( sort keys(%hosts) ) {
        my $owner = $hosts{$host};
        push( @list, [ $host, "$host [$owner]" ] );
    }

    &PrintViewList(@list);
}
elsif ( $mode eq "byip" ) {
    my $dns = new NetMaint::DNS;
    my $net = new NetMaint::Network;

    my @recs       = $dns->Search_A_Records_Address( $search, 1000 );
    my @ptr_recs   = $dns->Search_PTR_Records_IP_Exact($search);
    my %alloc_info = $net->GetAddressDetail($search);

    my @list;
    my $rec;
    my %seen = ();
    foreach my $rec (@recs) {
        my $host = $rec->{name};
        my $ip   = $rec->{address};

        next if ( $host =~ /^dyn-.*/o );
        next if ( $seen{$host} );
        push( @list, [ $host, "$host [$ip]" ] );
        $seen{$host} = 1;
    }

    foreach my $rec (@ptr_recs) {
        my $host = $rec->{address};
        my $ip   = $rec->{name};

        next if ( $seen{$host} );
        push( @list, [ $host, "$host [$ip]" ] );
        $seen{$host} = 1;
    }

    if ( $alloc_info{host} && !$seen{ $alloc_info{host} } ) {
        my $host = $alloc_info{host};
        my $ip   = $alloc_info{ip};
        push( @list, [ $host, "$host [$ip]" ] );
    }

    &PrintViewList(@list);
}
elsif ( $mode eq "bydomainexact" ) {
    my $hosts = new NetMaint::Hosts;
    my @hosts = $hosts->SearchByDomainExact( $search, 1000 );

    my @list;
    foreach my $host ( sort @hosts ) {
        push( @list, [ $host, $host ] );
    }

    &PrintViewList(@list);
}
elsif ( $mode eq "byether" ) {
    my $dhcp = new NetMaint::DHCP;
    my $util = new NetMaint::Util;

    $search =~ tr/A-Fa-f0-9//cd;

    my %hosts = $dhcp->SearchByEther( $search, 1000 );

    my @list;
    foreach my $host ( sort( keys(%hosts) ) ) {
        my @ethers = @{ $hosts{$host} };
        my @pretty = ();

        foreach my $eth (@ethers) {
            push( @pretty, $util->FormatEther($eth) );
        }

        push( @list, [ $host, "$host [" . join( ", ", @pretty ) . "]" ] );
    }

    &PrintViewList(@list);
}

$html->PageFooter();

# Begin-Doc
# Name: PrintViewList
# Description: display table of matching hosts and/or auto-redirect if single match
# Syntax: &PrintViewList(@hosts)
# End-Doc
sub PrintViewList {
    my @hosts = @_;
    my $cnt   = 0;

    if ( $#hosts < 0 ) {
        print "<h3>No matches found searching for '<tt>${search}</tt>'.</h3>\n";
        return;
    }

    # If we have only one host in the search results, try to immediately
    # refresh to the view page for that host.
    if ( $#hosts == 0 ) {
        my ( $host, $label ) = @{ $hosts[0] };

        print "<meta http-equiv=\"Refresh\" content=\"0; URL=";
        print "view-host.pl?host=" . $host . "\">\n";
    }

    &HTMLStartForm( "view-host.pl", "GET" );

    print "Matching hosts: ";
    &HTMLStartSelect( "host", 1 );
    foreach my $row (@hosts) {
        my ( $host, $label ) = @{$row};
        print "<option value=\"$host\">$label\n";
        $cnt++;
    }
    if ( $cnt >= 999 ) {
        print "<option value=\"\"> - list may be incomplete, max records reached -\n";
    }
    &HTMLEndSelect();
    &HTMLSubmit("View Host");
    &HTMLEndForm();

    print "<p/>\n";

    $html->StartBlockTable( "Matching Hosts", 750 );
    $html->StartInnerTable( "Hostname", "Ethernet Address", "Options" );

    foreach my $row (@hosts) {
        my ( $host, $label ) = @{$row};

        $html->StartInnerRow();
        print "<td>$label</td>\n";

        print "<td><tt>";
        my @ethers = sort( $dhcp->GetEthers($host) );
        my $elist  = $util->FormatEtherList(@ethers);
        $elist =~ s|\, |<br/>\n|gio;
        print $elist;
        print "</td>\n";

        print "<td>";
        print "<a href=\"view-host.pl?host=${host}\">View Details</a> | ";
        print "<a href=\"edit-host.pl?host=${host}&mode=view\">Edit Host</a> | ";
        print "<a href=\"edit-host.pl?host=${host}&mode=deletehost\">Delete Host</a> | ";
        print "Visit Host: <a href=\"http://${host}\">http</a> <a href=\"https://${host}\">https</a>";
        print "</td>\n";
        $html->EndInnerRow();
    }

    if ( $cnt >= 999 ) {
        $html->StartInnerRow();
        print "<td colspan=3>Maximum matches listed, try a narrower search.</td>\n";
        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();

}
