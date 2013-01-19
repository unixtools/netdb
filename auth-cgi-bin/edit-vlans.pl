#!/usr/bin/perl

# Begin-Doc
# Name: edit-vlans.pl
# Type: script
# Description: edit vlan information
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
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Register;
require NetMaint::Logging;

use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Edit VLANs" );
my $util = new NetMaint::Util;
my $net  = new NetMaint::Network;
my $log  = new NetMaint::Logging;
my $dhcp = new NetMaint::DHCP;

$html->PageHeader();
$html->RequirePriv("netdb-admin");

$log->Log();

my $mode = $rqpairs{mode} || "listvlans";

my $vlan  = $rqpairs{vlan};
my $name  = $rqpairs{name};
my $notes = $rqpairs{notes};

print "<b><a href=\"", &HTMLScriptURL, "\">Refresh to vlan listing</a></b><p/>\n";

if ( $mode eq "listvlans" ) {
    &DisplayVLANList();
    &DisplayAddVLAN();
}
elsif ( $mode eq "Create VLAN" ) {

    print "<h3>Creating vlan $vlan with name $name.</h3>\n";
    $net->CreateVLAN( $vlan, $name, $notes );
    print "<h3>VLAN created.</h3>\n";

    &DisplayVLANList();
    &DisplayAddVLAN();
}
elsif ( $mode eq "Delete VLAN" ) {
    my $verify = $rqpairs{verify};

    if ( $verify eq "yes" ) {
        $net->DeleteVLAN($vlan);

        &DisplayVLANList();
        &DisplayAddVLAN();
    }
    else {
        print "Are you sure you want to delete vlan '$vlan'?<p/>\n";
        print "<a href=\"", &HTMLScriptURL, "?mode=Delete+VLAN&";
        print "vlan=$vlan&verify=yes\">Yes, delete it.</a>\n";
    }
}
elsif ( $mode eq "Edit VLAN Details" ) {
    &DisplayVLANDetails($vlan);
}
elsif ( $mode eq "Change VLAN Details" ) {
    print "<h3>Updating vlan $vlan with name $name.</h3>\n";
    $net->ChangeVLAN( $vlan, $name, $notes );
    print "<h3>VLAN updated.</h3>\n";

    &DisplayVLANList();
    &DisplayAddVLAN();
}

print "<p/>\n";
$html->PageFooter();

# Begin-Doc
# Name: DisplayVLANList
# Description: output html for displaying selectable list of vlans
# End-Doc
sub DisplayVLANList {
    my $vlans = $net->GetVLANs();

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Available VLANs:<p/>";
    &HTMLStartSelect( "vlan", 20 );
    foreach my $vlan ( sort { $a <=> $b } keys %$vlans ) {

        my $notes = $vlans->{$vlan}->{notes};
        $notes =~ s/\n/ /sgmo;
        $notes = substr( $notes, 0, 100 );
        if ( $notes ne "" ) {
            $notes = " (" . $notes . " ...)";
        }

        print "<option value=\"$vlan\">$vlan: ", $vlans->{$vlan}->{name}, " $notes\n";
    }
    &HTMLEndSelect();
    print "<p/>\n";
    &HTMLSubmit( "Edit VLAN Details", "mode" );
    print " ";
    &HTMLSubmit( "Delete VLAN", "mode" );
    print "<p/>\n";
    &HTMLEndForm();
}

# Begin-Doc
# Name: DisplayVLANDetails
# Description: output html for editing vlan details
# End-Doc
sub DisplayVLANDetails {
    my $vlan = shift @_;

    print "<p/><hr/><p/>\n";
    print "<h3>Edit VLAN Details:</h3>\n";

    my $vlans = $net->GetVLANs();

    my $name  = $vlans->{$vlan}->{name};
    my $notes = $vlans->{$vlan}->{notes};

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "vlan", $vlan );
    print "VLAN: $vlan<br/>\n";
    print "Name: ";
    &HTMLInputText( "name", 30, $name );
    print "<br/>";
    print "Notes: ";
    &HTMLTextArea( "notes", $notes, 70, 8, "BOTH" );
    print "<p/>";
    &HTMLSubmit( "Change VLAN Details", "mode" );
    &HTMLEndForm();
}

# Begin-Doc
# Name: DisplayAddVLAN
# Description: output html for new-vlan form
# End-Doc
sub DisplayAddVLAN {
    print "<p/><hr/><p/>\n";
    print "<h3>Create New VLAN:</h3>\n";

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "VLAN: ";
    &HTMLInputText( "vlan", 6 );
    print "<br/>";
    print "Name: ";
    &HTMLInputText( "name", 30 );
    print "<br/>";
    print "Notes: ";
    &HTMLTextArea( "notes", "", 70, 8, "BOTH" );
    print "<p/>";
    &HTMLSubmit( "Create VLAN", "mode" );
    &HTMLEndForm();
}
