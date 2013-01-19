#!/usr/bin/perl

# Begin-Doc
# Name: edit-ip-alloc.pl
# Type: script
# Description: edit ip address/subnet allocations
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::PrivSys;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Register;
require NetMaint::Logging;

use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Edit Subnets and IP Allocations" );
my $util = new NetMaint::Util;
my $net  = new NetMaint::Network;
my $log  = new NetMaint::Logging;
my $dhcp = new NetMaint::DHCP;

$html->PageHeader();
$html->RequirePriv("sysprog:netdb:alloc");

$log->Log();

my $mode = $rqpairs{mode} || "listsubnets";

my $subnet    = $rqpairs{subnet};
my $subnetip  = $rqpairs{subnetip};
my $mask      = $rqpairs{netmask};
my $alloc     = $rqpairs{alloc};
my $addresses = $rqpairs{addresses};
my $vlan      = $rqpairs{vlan};
my $notes     = $rqpairs{notes};
my $desc      = $rqpairs{description};
my $tmpl      = $rqpairs{template};

print "<b><a href=\"", &HTMLScriptURL, "\">Refresh to subnet listing</a></b><p/>\n";

if ( $mode eq "listsubnets" ) {
    &DisplaySubnetList();
    &DisplayAddSubnet();
}
elsif ( $mode eq "Create Subnet" ) {
    my $maskedsubnet = $net->MaskAddress( $subnetip, $mask );
    if ( $maskedsubnet ne $subnetip ) {
        $html->ErrorExit("Subnet doesn't match with mask.");
    }
    else {
        if ( my $err = $net->CheckSubnetOverlap( $subnetip, $mask ) ) {
            $html->ErrorExit($err);
        }

        print "<h3>Creating subnet $subnetip with mask $mask with template $tmpl.</h3>\n";
        $net->CreateSubnet( $subnetip, $mask, $desc, $vlan, $tmpl, $notes );
        print "<h3>Subnet created.</h3>\n";

        $dhcp->TriggerUpdate();
    }

    &DisplaySubnetList();
    &DisplayAddSubnet();
}
elsif ( $mode eq "Delete Subnet" ) {
    my $verify = $rqpairs{verify};

    my $info = $net->GetAddressesDetail($subnet);
    my $ok   = 1;
    foreach my $addr ( keys(%$info) ) {
        if ( $info->{$addr}->{host} ) {
            $ok = 0;
            print "Subnet contains allocated host: ";
            print $info->{$addr}->{host}, " on ip ";
            print $info->{$addr}->{ip},   ".<br/>\n";

            $html->ErrorExit("Cannot delete subnet with allocated IPs.");
        }
    }

    if ($ok) {
        if ( $verify eq "yes" ) {
            $net->DeleteSubnet($subnet);
            $dhcp->TriggerUpdate();

            &DisplaySubnetList();
            &DisplayAddSubnet();
        }
        else {
            print "Are you sure you want to delete subnet '$subnet'?<p/>\n";
            print "<a href=\"", &HTMLScriptURL, "?mode=Delete+Subnet&";
            print "subnet=$subnet&verify=yes\">Yes, delete it.</a>\n";
        }
    }
    else {
        print "<h3>Cannot delete subnet, contains addresses assigned to hosts.</h3>\n";
        &DisplaySubnetList();
        &DisplayAddSubnet();
    }
}
elsif ( $mode eq "Edit Subnet Details" ) {
    &DisplaySubnetDetails($subnet);
}
elsif ( $mode eq "Edit Subnet Allocations" ) {
    &DisplayIPList($subnet);
}
elsif ( $mode eq "Change Subnet Details" ) {
    print "<h3>Updating subnet $subnetip with desc, vlan, template, and notes.</h3>\n";
    $net->ChangeSubnet( $subnet, $desc, $vlan, $tmpl, $notes );
    $dhcp->TriggerUpdate();
    print "<h3>Subnet updated.</h3>\n";

    &DisplaySubnetList();
    &DisplayAddSubnet();
}
elsif ( $mode eq "Change Allocation" ) {
    my $newalloc = $rqpairs{alloc};
    my @addrs = split( ' ', $rqpairs{addresses} );

    $dhcp->BlockUpdates();

    print "<ul>\n";
    foreach my $addr (@addrs) {
        print "<li>$addr: ";
        my %info = $net->GetAddressDetail($addr);

        if ( $info{type} eq $newalloc ) {
            print "skipped, allocation unchanged.";
        }
        elsif ($info{type} ne "dynamic"
            && $newalloc   ne "dynamic"
            && $newalloc   ne "unreg"
            && $info{type} ne "unreg" )
        {
            print "updating allocation to '$newalloc'.";
            $net->SetIPAllocation( $addr, $newalloc );
            $dhcp->TriggerUpdate();
        }
        elsif ( $info{host} ) {
            print "skipped, is allocated to a host.";
        }
        else {
            print "updating allocation to '$newalloc'.";
            $net->SetIPAllocation( $addr, $newalloc );
            $dhcp->TriggerUpdate();
        }
        print "\n";
    }
    print "</ul>\n";

    $dhcp->UnblockUpdates();

    &DisplayIPList($subnet);
}

print "<p/>\n";
$html->PageFooter();

# Begin-Doc
# Name: DisplayIPList
# Type: function
# Description: output form/html to display selectable list of ip addresses on subnet
# Syntax: &DisplayIPList();
# End-Doc
sub DisplayIPList {
    my $subnet = shift;

    my $info  = $net->GetAddressesDetail($subnet);
    my @addrs = $net->NetworkSort( keys( %{$info} ) );

    &HTMLStartForm( &HTMLScriptURL(), "POST" );
    print "IP Addresses on subnet $subnet:<p/>";
    &HTMLHidden( "subnet", $subnet );
    &HTMLStartSelect( "addresses", 20, 1 );
    foreach my $addr (@addrs) {
        my $type = $info->{$addr}->{type};
        my $host = $info->{$addr}->{host};

        print "<option value=\"$addr\">$addr - $type";
        if ($host) {
            print " [$host]";
        }
        print "\n";
    }
    &HTMLEndSelect();
    print "<p/>\n";

    print "Change allocation of selected IPs to: ";
    &HTMLStartSelect( "alloc", 1 );
    print "<option>free\n";
    print "<option>static\n";
    print "<option>reserved\n";
    print "<option>dynamic\n";
    print "<option>unreg\n";
    print "<option>special\n";
    print "<option>restricted\n";
    print "<option>installation\n";
    &HTMLEndSelect;
    &HTMLSubmit( "Change Allocation", "mode" );

    &HTMLEndForm();
}

# Begin-Doc
# Name: DisplaySubnetList
# Type: function
# Description: output form/html to display selectable list of subnets
# Syntax: &DisplaySubnetList();
# End-Doc
sub DisplaySubnetList {
    $net->ClearCache();

    my $info    = $net->GetSubnets();
    my @subnets = $net->NetworkSort( keys( %{$info} ) );

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Available Subnets:<p/>";
    &HTMLStartSelect( "subnet", 20 );
    foreach my $sn (@subnets) {
        print "<option value=\"$sn\">$sn - " . "["
            . $info->{$sn}->{vlan} . "] ["
            . $info->{$sn}->{template} . "] "
            . $info->{$sn}->{description} . "\n";
    }
    &HTMLEndSelect();
    print "<p/>\n";
    &HTMLSubmit( "Edit Subnet Allocations", "mode" );
    print " ";
    &HTMLSubmit( "Edit Subnet Details", "mode" );
    print " ";
    &HTMLSubmit( "Delete Subnet", "mode" );
    print "<p/>\n";
    &HTMLEndForm();
}

# Begin-Doc
# Name: DisplaySubnetDetails
# Type: function
# Description: output form/html to edit subnet details
# Syntax: &DisplaySubnetDetails();
# End-Doc
sub DisplaySubnetDetails {
    my $sn = shift @_;

    print "<p/><hr/><p/>\n";
    print "<h3>Edit Subnet Details:</h3>\n";

    my $subnets = $net->GetSubnets();

    my $desc   = $subnets->{$sn}->{description};
    my $snvlan = $subnets->{$sn}->{vlan};
    my $sntmpl = $subnets->{$sn}->{template};
    my $notes  = $subnets->{$sn}->{notes};

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "subnet", $sn );
    print "Subnet: $sn<br/>\n";
    print "Description: ";
    &HTMLInputText( "description", 30, $desc );
    print "<br/>\n";

    my $vlans = $net->GetVLANs();

    print "VLAN: ";
    &HTMLStartSelect( "vlan", 1 );
    print "<option value=\"\" ", $snvlan eq "" ? " selected" : "", ">None</option>\n";
    foreach my $vlan ( sort { $a <=> $b } keys %$vlans ) {
        print "<option value=\"$vlan\" ", $snvlan eq $vlan ? " selected" : "",
            ">$vlan: ", $vlans->{$vlan}->{name}, "</option>\n";
    }
    &HTMLEndSelect();
    print "<br/>";
    print "Template: ";
    &HTMLStartSelect( "template", 1 );
    foreach my $opttmpl ( "Standard", "VOIP", "Public", "Short" ) {
        my $lctmpl = lc $opttmpl;
        print "<option value=\"$lctmpl\" ", $sntmpl eq $lctmpl ? " selected" : "", ">$opttmpl</option>\n";
    }
    &HTMLEndSelect();
    print "<br/>";
    print "Notes: ";
    &HTMLTextArea( "notes", $notes, 70, 8, "BOTH" );
    print "<br/>";
    &HTMLSubmit( "Change Subnet Details", "mode" );
    &HTMLEndForm();
}

# Begin-Doc
# Name: DisplayAddSubnet
# Type: function
# Description: output form/html to add a new subnet
# Syntax: &DisplayAddSubnet();
# End-Doc
sub DisplayAddSubnet {
    print "<p/><hr/><p/>\n";
    print "<h3>Create New Subnet:</h3>\n";

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Description: ";
    &HTMLInputText( "description", 30 );
    print "<br/>";
    print "Subnet Network IP: ";
    &HTMLInputText( "subnetip", 20 );
    print "<br/>";
    print "Netmask: ";
    &HTMLStartSelect("netmask");

    for ( my $i = 21; $i < 31; $i++ ) {
        my $mask = $net->BitsToMask($i);

        print "<option value=$mask>$mask: /$i\n";
    }
    &HTMLEndSelect();
    print "<br/>";

    my $vlans = $net->GetVLANs();

    print "VLAN: ";
    &HTMLStartSelect( "vlan", 1 );
    print "<option value=\"\">None</option>\n";
    foreach my $vlan ( sort { $a <=> $b } keys %$vlans ) {
        print "<option value=\"$vlan\">$vlan: ", $vlans->{$vlan}->{name}, "</option>\n";
    }
    &HTMLEndSelect();
    print "<br/>";
    print "Template: ";
    &HTMLStartSelect( "template", 1 );
    foreach my $opttmpl ( "Standard", "VOIP", "Public", "Short" ) {
        my $lctmpl = lc $opttmpl;
        print "<option value=\"$lctmpl\">$opttmpl</option>\n";
    }
    &HTMLEndSelect();
    print "<br/>";
    print "Notes: ";
    &HTMLTextArea( "notes", "", 70, 8, "BOTH" );
    print "<br/>";
    &HTMLSubmit( "Create Subnet", "mode" );
    &HTMLEndForm();
}
