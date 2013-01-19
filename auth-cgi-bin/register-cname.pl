#!/usr/bin/perl

# Begin-Doc
# Name: register-cname.pl
# Type: script
# Description: service cname registration tool
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use UMR::PrivSys;
use UMR::AuthSrv;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Register;
require NetMaint::Logging;

&HTMLGetRequest();
&HTMLContentType();

my $html     = new NetMaint::HTML( title => "Register CName" );
my $hosts    = new NetMaint::Hosts;
my $dhcp     = new NetMaint::DHCP;
my $util     = new NetMaint::Util;
my $dns      = new NetMaint::DNS;
my $access   = new NetMaint::Access;
my $register = new NetMaint::Register;
my $log      = new NetMaint::Logging;

$html->PageHeader();
print "<p/>\n";

$html->StartBlockTable( "CName Registration Instructions", 500 );
$html->StartInnerTable();
$html->StartInnerRow();
print "<td>\n";
print "This web tool is used to register service cnames for a set\n";
print "list of known services. Hostname must be entered in lowercase\n";
print "and must have one or more (a-z,0-9,-) components, and end in\n";
print ".mst.edu\n";
print "<p/>\n";
print "To update an existing cname, just submit as if you were adding\n";
print "it new, or delete it and re-add.\n";
print "</tr>\n";
$html->EndInnerRow();
$html->EndInnerTable();
$html->EndBlockTable();

print "<p/>\n";

#
# Build up a list of targets that this user is authorized for
#
my @targets = &GetAuthorizedTargets();
my %auth_targets;
foreach my $target (@targets) {
    $auth_targets{$target} = 1;
}

if ( !@targets ) {
    $html->ErrorExit("You do not have any CName Manager permissions.");
}

my @recs = ();
my %auth_cnames;
foreach my $target (@targets) {
    my @tmprecs = $dns->Get_CNAME_Records_Target($target);
    foreach my $rec (@tmprecs) {

        # Don't allow editing odd format names, and don't display them either
        next if ( $rec->{name} !~ /^([a-z0-9\-]+\.)+mst\.edu$/ );
        push( @recs, $rec );
        $auth_cnames{ $rec->{name} } = 1;
    }
}

#
# Now process any updates in current request including outputting any errors/warnings
#
my $mode   = $rqpairs{mode};
my $reload = 0;
if ( $mode eq "add" ) {
    my $hostname = $rqpairs{hostname};
    my $target   = $rqpairs{target};
    my $info     = $hosts->GetHostInfo($hostname);

    if ( !$target ) {
        $html->ErrorWarn("Must select a target address.");
    }
    elsif ( $hostname !~ /^([a-z0-9\-]+\.)+mst\.edu$/ ) {
        $html->ErrorWarn(
            "CName address ($hostname) not valid, one or more (a-z, 0-9, -) components followed by mst.edu only.");
    }
    elsif ( !$auth_targets{$target} ) {
        $html->ErrorWarn("Not authorized to add cnames pointing at that target address.");
    }
    elsif ( $info && $info->{type} ne "cname" ) {
        $html->ErrorWarn("Hostname already exists, and is not a cname.");
    }
    elsif ( $info && !$auth_cnames{$hostname} ) {
        $html->ErrorWarn("Hostname already exists, and is a cname, but not one you have access to update.");
    }
    elsif ($info) {
        print "Updating cname $hostname to point to $target.\n";

        $dns->BlockUpdates();
        $dns->Delete_CNAME_Record($hostname);
        $dns->Update_CNAME_Record( $hostname, $target );
        $dns->UnblockUpdates();
        $hosts->MarkUpdated($hostname);

        $reload = 1;
    }
    elsif ( !$info ) {
        print "Creating cname $hostname pointing at $target.\n";

        my $domain = $hostname;
        $domain =~ s/^[^\.]+\.//;

        $hosts->CreateHost(
            host   => $hostname,
            domain => $domain,
            type   => "cname",
            owner  => "namesrv"
        );

        $dns->BlockUpdates();
        $dns->Delete_CNAME_Record($hostname);
        $dns->Update_CNAME_Record( $hostname, $target );
        $dns->UnblockUpdates();

        $reload = 1;
    }
}
elsif ( $mode eq "delete" ) {
    my $hostname = $rqpairs{hostname};
    my $info     = $hosts->GetHostInfo($hostname);

    if ( !$info ) {
        $html->ErrorWarn("Hostname does not exist.");
    }
    elsif ( $info && $info->{type} ne "cname" ) {
        $html->ErrorWarn("Hostname already exists, and is not a cname.");
    }
    elsif ( $info && !$auth_cnames{$hostname} ) {
        $html->ErrorWarn("Hostname already exists, and is a cname, but not one you have access to update.");
    }
    else {
        if ( $rqpairs{verify} ne "yes" ) {
            print "Are you sure you want to delete cname $hostname?\n";
            print "<a href=\"?mode=delete&verify=yes&hostname=$hostname\">Yes, delete it.</a>\n";
        }
        else {
            print "Deleting cname $hostname.\n";
            $dns->DeleteHost($hostname);
            $hosts->DeleteHost($hostname);

            $reload = 1;
        }
    }
}

#
# Reload data if needed
#
if ($reload) {
    %auth_cnames = ();
    @recs        = ();

    foreach my $target (@targets) {
        my @tmprecs = $dns->Get_CNAME_Records_Target($target);
        foreach my $rec (@tmprecs) {

            # Don't allow editing odd format names, and don't display them either
            next if ( $rec->{name} !~ /^([a-z0-9\-]+\.)+mst\.edu$/ );
            push( @recs, $rec );
            $auth_cnames{ $rec->{name} } = 1;
        }
    }
}

#
# Now display the table of current cnames
#

$html->StartBlockTable("Current CName Definitions");
$html->StartInnerTable( "Hostname", "Target", "Options" );

&DisplayAddForm();

foreach my $rec ( sort { $a->{name} cmp $b->{name} } @recs ) {
    $html->StartInnerRow();
    print "<td>", $rec->{name},    "</td>\n";
    print "<td>", $rec->{address}, "</td>\n";
    print "<td>", "<a href=\"?mode=delete&hostname=", $rec->{name}, "\">Delete</a>", "</td>\n";
    $html->EndInnerRow();
}

&DisplayAddForm();

$html->EndInnerTable();
$html->EndBlockTable();

# Begin-Doc
# Name: GetAuthorizedTargets
# Type: function
# Description: Returns a list of authorized cname targets for current remote user
# Syntax: @targets = &GetAuthorizedTargets();
# End-Doc
sub GetAuthorizedTargets {
    my @targets = ();
    my %privs   = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );
    foreach my $priv (%privs) {
        if ( $priv =~ /^sysprog:netdb:cname-manager:(.+)$/o ) {
            push( @targets, $1 );
        }
    }
    return @targets;
}

# Begin-Doc
# Name: DisplayAddForm
# Type: function
# Description: Outputs the form to add or update a cname
# Syntax: &DisplayAddForm();
# End-Doc
sub DisplayAddForm {
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "mode", "add" );
    $html->StartInnerHeaderRow();
    print "<td>";
    &HTMLInputText( "hostname", 30 );
    print "</td>\n";
    print "<td>\n";
    &HTMLStartSelect( "target", 1 );
    print "<option value=\"\">Select target host...\n";

    foreach my $target ( sort(@targets) ) {
        print "<option>$target\n";
    }
    &HTMLEndSelect();
    print "</td>\n";
    print "<td>\n";
    &HTMLSubmit("Add or Update CName");
    print "</td>\n";
    $html->EndInnerHeaderRow();
    &HTMLEndForm();
}
