#!/usr/bin/perl

# Begin-Doc
# Name: register-clc.pl
# Type: script
# Description: registration tool for easy bulk clc registration
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
require NetMaint::Access;
require NetMaint::Register;
require NetMaint::Logging;

&HTMLGetRequest();
&HTMLContentType();

my $html     = new NetMaint::HTML( title => "Register CLC Systems" );
my $hosts    = new NetMaint::Hosts;
my $dhcp     = new NetMaint::DHCP;
my $util     = new NetMaint::Util;
my $dns      = new NetMaint::DNS;
my $access   = new NetMaint::Access;
my $register = new NetMaint::Register;
my $log      = new NetMaint::Logging;

$html->PageHeader();

my $owner = "deskinst";
my $nametype = $rqpairs{nametype} || "clcname";

if (   $nametype ne "clcname"
    && $nametype ne "virtclcname"
    && $nametype ne "thinclcname" )
{
    $html->ErrorExit("Invalid name type.");
}

my $clc = lc $rqpairs{"clc"};
if ( !$clc ) {
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "CLC: ";
    &HTMLHidden( "mode", "editclc" );
    &HTMLInputText( "clc", 10 );
    print " ";
    &HTMLSubmit("Edit or Create CLC");
    &HTMLEndForm();

    $html->PageFooter();
    exit;
}

$log->Log( owner => $owner );

if ( $clc !~ /^[a-z0-9-]+$/o || length($clc) > 6 ) {
    $html->ErrorExit("Invalid CLC name.");
}

print "<h2>Editing CLC Hosts for CLC <tt>$clc</tt>:</h2>\n";

print "<a href=\"?clc=$clc\">Refresh Listing</a><p/>\n";

my $mode = $rqpairs{mode};
if ( $mode eq "register" ) {
    my $domain = $rqpairs{domain};
    my $ether  = $rqpairs{ether};
    my $index  = $rqpairs{index};
    my $image  = $rqpairs{image};

    if (!$access->Check(
            type   => "desktop",
            flag   => $nametype,
            domain => $domain,
            action => "insert",
        )
        )
    {
        $html->ErrorExit("Permission denied.");
    }

    # should check ether address validity
    # also need to check reg quota here.

    my $hostname;
    if ( $nametype eq "clcname" ) {
        $hostname = sprintf( "rc%.2d%s%s.%s", int($index), $image, $clc, $domain );
    }
    elsif ( $nametype eq "virtclcname" ) {
        $hostname = sprintf( "rcv%.2d%s%s.%s", int($index), $image, $clc, $domain );
    }
    elsif ( $nametype eq "thinclcname" ) {
        $hostname = sprintf( "rcx%.2d%s%s.%s", int($index), $image, $clc, $domain );
    }
    else {
        $html->ErrorExit("Can't handle name type ($nametype)");
    }

    my $res = $register->RegisterDesktop(
        host   => $hostname,
        owner  => $owner,
        domain => $domain,
        ether  => $ether
    );

    if ($res) {
        print "<h3>$res</h3>\n";
        $log->Log(
            host   => $hostname,
            ether  => $ether,
            status => "failed",
            msg    => $res
        );
    }
    else {
        print "<h3>Machine registered.</h3>\n";
        $log->Log(
            owner  => $owner,
            host   => $hostname,
            ether  => $ether,
            status => "ok"
        );
    }
}
elsif ( $mode eq "delete" ) {
    my $host = lc $rqpairs{host};

    my $verify = $rqpairs{"verify"};

    my $hinfo = $hosts->GetHostInfo($host);

    if ( $hinfo->{adminlock} ) {
        if (!$access->CheckAllDomains(
                userid => $ENV{REMOTE_USER},
                flag   => "adminlock",
                action => "delete",
            )
            )
        {
            $log->Log(
                owner  => $owner,
                host   => $host,
                status => "denied - adminlock"
            );
            print "<h3>Permission Denied, Machine Administratively Locked.</h3>\n";
            $html->PageFooter();
            return 0;
        }
    }

    if ( $verify ne "yes" ) {
        print "Are you sure you want to delete host ($host)? ";

        print "<p/>\n";

        print "<a href=\"?clc=$clc&mode=delete&host=$host&verify=yes\">Yes, delete it.</a>\n";
        print " ";
        print "<a href=\"?clc=$clc\">No, don't delete the host.</a>\n";
        print "<p/>\n";

        $html->PageFooter();
        exit;
    }
    else {
        $register->DeleteHost($host);
        $log->Log( owner => $owner, host => $host, status => "ok" );
    }

}

#
# Print out existing registration list
#
my @hosts = sort( $hosts->SearchByCLCName( $clc, 1000 ) );

if ( $mode eq "" || $mode eq "editclc" ) {
    $html->StartMailWrapper("Hosts in CLC $clc");
}

if ($access->Check(
        type   => "desktop",
        flag   => "clcname",
        action => "insert"
    )
    )
{
    $html->StartBlockTable( "Register New Host", 800 );
    $html->StartInnerTable();

    $html->StartInnerRow();

    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "clc",      $clc );
    &HTMLHidden( "mode",     "register" );
    &HTMLHidden( "nametype", $nametype );

    # Note which hosts to skip in list
    my %skip_numbers = ();
    foreach my $host (@hosts) {
        if ( $host =~ /rc(\d\d)/o ) {
            $skip_numbers{ int($1) } = 1;
        }
    }

    print "<td width=50%><b>Hostname:</b> <tt>";
    if ( $nametype eq "clcname" ) {
        print "rc";
    }
    elsif ( $nametype eq "virtclcname" ) {
        print "rcv";
    }
    elsif ( $nametype eq "thinclcname" ) {
        print "rcx";
    }
    else {
        $html->ErrorExit("Can't handle name type ($nametype).");
    }

    &HTMLStartSelect( "index", 1 );
    for ( my $i = 1; $i <= 99; $i++ ) {
        if ( !$skip_numbers{$i} ) {
            print "<option>", sprintf( "%.2d", $i ), "\n";
        }
    }
    &HTMLEndSelect();

    &HTMLStartSelect( "image", 1 );
    foreach my $image ( 'a' .. 'z' ) {
        print "<option>$image\n";
    }
    &HTMLEndSelect();

    print $clc;
    print ".</tt>";

    my %domains = $dns->GetDomains();
    &HTMLStartSelect( "domain", 1 );
    foreach my $domain ( sort( keys(%domains) ) ) {
        next if ( !$hosts->CheckValidNameTypeDomain( type => "desktop", nametype => $nametype, domain => $domain ) );

        if ($access->Check(
                type   => "desktop",
                flag   => $nametype,
                domain => $domain,
                action => "insert",
            )
            )
        {
            if ( $domain eq "managed.mst.edu" ) {
                print "<option selected>$domain\n";
            }
            else {
                print "<option>$domain\n";
            }
        }
    }
    &HTMLEndSelect();
    print "</td>\n";
    print "<td><b>Ethernet Address:</b> ";
    &HTMLInputText( "ether", 25 );
    print "</td>\n";
    print "<td>\n";
    &HTMLSubmit("Register");
    &HTMLEndForm();

    print "</td>\n";
    $html->EndInnerRow();

    my @nt = (
        [ "clcname",     "Standard CLC Name" ],
        [ "virtclcname", "Virtual CLC Name" ],
        [ "thinclcname", "Thin Client CLC Name" ]
    );
    my @links = ();
    foreach my $ntref (@nt) {
        my ( $type, $label ) = @$ntref;

        if ( $nametype eq $type ) {
            push( @links, "<b>$label</b>" );
        }
        else {
            push( @links, "<a href=\"?nametype=$type&clc=$clc\">$label</a>" );
        }
    }

    $html->StartInnerRow();
    print "<td align=center colspan=3>Switch to hostname type: ";
    print join( " | ", @links );
    print "</td>\n";

    $html->EndInnerRow();

    $html->EndInnerTable();
    $html->EndBlockTable();

    print "<p/>\n";
}

$html->StartBlockTable( "Hosts in CLC $clc", 800 );
$html->StartInnerTable( "Host", "Ethernet Address", "Options" );

my $ethercnt = 0;
foreach my $host (@hosts) {
    $html->StartInnerRow();
    print "<td><tt><a href=\"view-host.pl?host=$host\">$host</a></td>\n";

    my @ethers = sort( $dhcp->GetEthers($host) );
    $ethercnt += $#ethers + 1;
    print "<td><tt>";
    print $util->FormatEtherList(@ethers);
    print "</td>\n";

    print "<td>";

    print "<a href=\"view-host.pl?host=$host\">View</a> | ";
    print "<a href=\"edit-host.pl?mode=view&host=$host\">Edit</a> | ";
    print "<a href=\"?mode=delete&clc=$clc&host=$host&nametype=$nametype\">Delete</a>";
    print "</td>\n";

    $html->EndInnerRow();
}

$html->StartInnerRow();
print "<td colspan=3>";
print "To add/remove additional ethernet addresses or change other host details, click \"Edit Host\".\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td colspan=3>";
print "<b>Current Systems in this CLC:</b> ", $ethercnt, "</td>\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();
if ( $mode eq "" || $mode eq "editclc" ) {
    $html->EndMailWrapper();
}

$html->PageFooter();

