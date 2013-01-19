#!/usr/bin/perl

# Begin-Doc
# Name: register-desktop.pl
# Type: script
# Description: user desktop registration tool
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::PrivSys;
use Local::AuthSrv;
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

my $html     = new NetMaint::HTML( title => "Register Desktop" );
my $hosts    = new NetMaint::Hosts;
my $dhcp     = new NetMaint::DHCP;
my $util     = new NetMaint::Util;
my $dns      = new NetMaint::DNS;
my $access   = new NetMaint::Access;
my $register = new NetMaint::Register;
my $log      = new NetMaint::Logging;

my %privs = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );

my $owner;
my $qryowner;

$html->PageHeader();
print "<p/>\n";

$html->StartBlockTable( "Desktop Registration Instructions", 500 );
$html->StartInnerTable();
$html->StartInnerRow();
print "<td>\n";
print "This web tool is used to register a computer's ethernet card so\n";
print "that it can be used to access network resources. This application\n";
print "should be used for registering all desktop and/or laptop computers\n";
print "that will be attached to the campus network.\n";
print "<p/>\n";
print "If you are registering a wireless card, you will also need to configure\n";
print "it for access to the campus network. Detailed instructions are\n";
print "<a href=\"http://it.mst.edu/services\">available</a>.\n";
print "</tr>\n";
$html->EndInnerRow();
$html->EndInnerTable();
$html->EndBlockTable();

print "<p/>\n";

my ( $owner, $qryowner );
if ( $privs{"sysprog:netdb:user-on-behalf"} ) {
    $owner = $rqpairs{"owner"};
    if ( $owner && !$util->UserInfo($owner) ) {
        $html->ErrorExit("Invalid owner, userid does not exist.");
    }

    if ( !$owner && $rqpairs{mode} ne "" ) {
        $owner = $ENV{REMOTE_USER};
    }
    elsif ( !$owner ) {

        # Only put form up on initial screen

        &HTMLStartForm( &HTMLScriptURL(), "GET" );
        print "Owner UserID: ";
        &HTMLInputText( "owner", 20 );
        &HTMLHidden( "ether", $rqpairs{ether} );
        &HTMLSubmit("Edit Hosts");
        &HTMLEndForm();
        $html->PageFooter();
        exit;
    }
    $qryowner = $owner;
}
else {
    $owner    = $ENV{REMOTE_USER};
    $qryowner = "";
}
$owner    = lc $owner;
$qryowner = lc $qryowner;

if ( length($owner) > 11 ) {
    $html->ErrorExit(
        "Owner named devices limited to 11 character owner names. Contact IT to make a custom registration.");
}

my $ether = $rqpairs{ether};
my $nametype = $rqpairs{nametype} || "ownername";
if (   $nametype ne "ownername"
    && $nametype ne "virtownername"
    && $nametype ne "thinname"
    && $nametype ne "travelname"
    && $nametype ne "virttravelname" )
{
    $html->ErrorExit("Invalid name type.");
}

$log->Log( owner => $owner );

my $mode = $rqpairs{mode};
if ( $mode eq "register" ) {
    my $domain = $rqpairs{domain};
    my $ether  = $rqpairs{ether};
    my $index  = $rqpairs{index};

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

    if ( $domain eq "" ) {
        $html->ErrorExit("Must specify domain.");
    }

    if ( $owner && !$util->UserInfo($owner) ) {
        $html->ErrorExit("Invalid owner, userid does not exist.");
    }

    if ( $rqpairs{"index"} eq "##" ) {
        my @free = $hosts->GetFreeIndexes( owner => $owner, nametype => $nametype );
        my $picked = shift @free;
        if ( !$picked ) {
            $html->ErrorExit("Unable to determine next available index. Contact Help Desk.");
        }
    }

    my $eth_check_msg = $util->CheckValidEther($ether);
    if ($eth_check_msg) {
        $html->ErrorExit($eth_check_msg);
    }

    my $eth_host_assigned = $dhcp->SearchByEtherExact($ether);
    if ( $ether && $eth_host_assigned ) {
        $html->ErrorExitRaw( "Ethernet address already assigned to '"
                . $html->SearchLink_HostEdit($eth_host_assigned)
                . "', host not created." );
    }

    my $hostname;
    if ( $nametype eq "ownername" ) {
        $hostname = sprintf( "r%.2d%s.%s", int($index), $owner, $domain );
    }
    elsif ( $nametype eq "virtownername" ) {
        $hostname = sprintf( "rv%.2d%s.%s", int($index), $owner, $domain );
    }
    elsif ( $nametype eq "thinname" ) {
        $hostname = sprintf( "rx%.2d%s.%s", int($index), $owner, $domain );
    }
    elsif ( $nametype eq "travelname" ) {
        $hostname = sprintf( "rt%.2d%s.%s", int($index), $owner, $domain );
    }

    if ( !$hostname ) {
        $html->ErrorExit("Unable to calculate hostname from parameters.");
    }

    my $err = $hosts->CheckNameLength( host => $hostname );
    if ($err) {
        $html->ErrorExit($err);
    }

    my $cnt   = $access->GetUsedQuota($owner);
    my $quota = $access->GetRegistrationQuota($owner);

    if ( $cnt >= $quota ) {
        $html->ErrorExit("Owner '$owner' is at or has exceeded registration quota. ($quota)");
    }

    my $res = $register->RegisterDesktop(
        owner  => $owner,
        host   => $hostname,
        domain => $domain,
        ether  => $ether
    );

    if ($res) {
        print "<h3>$res</h3>\n";
        $log->Log(
            owner  => $owner,
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
    if ( $hinfo->{owner} ne $owner ) {
        $log->Log( owner => $owner, host => $host, status => "denied" );
        $html->ErrorExit("Permission Denied.");
    }

    if ( $hinfo->{adminlock} ) {
        print "<h3>Machine administratively locked.</h3><p/>\n";
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
            $html->ErrorExit("Permission Denied, Machine Administratively Locked.");
        }
    }

    if ( $verify ne "yes" ) {
        print "Are you sure you want to delete host ($host)? ";

        print "<p/>\n";

        print "<a href=\"?owner=$qryowner&mode=delete&host=$host&verify=yes\">Yes, delete it.</a>\n";
        print " ";
        print "<a href=\"?owner=$qryowner\">No, don't delete the host.</a>\n";
        print "<p/>\n";

        $html->PageFooter();
        exit;
    }
    else {
        $register->DeleteHost($host);
        $log->Log( owner => $owner, host => $host, status => "ok" );
    }

}

$html->StartBlockTable( "Register New Host", 800 );
$html->StartInnerTable();

my @hosts = sort( $hosts->SearchByOwnerExact($owner) );

my $quota    = $access->GetRegistrationQuota($owner);
my $defquota = $access->GetDefaultRegistrationQuota($owner);
my $ethercnt = $access->GetUsedQuota($owner);

$html->StartInnerRow();
print "<td colspan=3 align=center>";
print "<b>$owner has $ethercnt ethernet addresses registered, out of a maximum of ";
print "$quota. (Userid default quota $defquota.)</b>\n";
$html->EndInnerRow();

if ( $ethercnt < $quota ) {

    if ( $access->Check( type => "desktop", flag => "ownername" ) ) {
        $html->StartInnerRow();
        print "<td align=center>\n";

        &HTMLStartForm( &HTMLScriptURL, "POST" );
        &HTMLHidden( "owner",    $qryowner );
        &HTMLHidden( "mode",     "register" );
        &HTMLHidden( "nametype", $nametype );

        print "<b>Hostname:</b> <tt>";
        if ( $nametype eq "ownername" ) {
            print "r";
        }
        elsif ( $nametype eq "virtownername" ) {
            print "rv";
        }
        elsif ( $nametype eq "thinname" ) {
            print "rx";
        }
        elsif ( $nametype eq "travelname" ) {
            print "rt";
        }

        &HTMLStartSelect( "index", 1 );
        foreach my $i ( $hosts->GetFreeIndexes( owner => $owner, nametype => $nametype ) ) {
            print "<option>$i\n";
        }
        print "<option value=\"##\">Auto</option>\n";
        &HTMLEndSelect();

        print $owner, ".</tt>";

        my %domains = $dns->GetDomains();
        my @domains = ();
        foreach my $domain ( sort( keys(%domains) ) ) {

            next
                if ( !$hosts->CheckValidNameTypeDomain( type => "desktop", nametype => $nametype, domain => $domain ) );

            if ($access->Check(
                    type   => "desktop",
                    flag   => "ownername",
                    domain => $domain,
                    action => "insert",
                )
                )
            {
                push( @domains, $domain );
            }
        }

        if ( $#domains > 0 ) {
            &HTMLStartSelect( "domain", 1 );
            my $did_sel = 0;
            foreach my $domain (@domains) {
                if ( $domain eq "device.mst.edu" && !$did_sel ) {
                    print "<option selected>$domain\n";
                }
                elsif ( $domain eq "managed.mst.edu" && !$did_sel ) {
                    print "<option selected>$domain\n";
                }
                else {
                    print "<option>$domain\n";
                }
            }
            &HTMLEndSelect();
            print " ";
        }
        else {
            print "<tt>device.mst.edu</tt>";
            &HTMLHidden( "domain", "device.mst.edu" );
        }

        print "</td><td><b>Ethernet Address:</b> \n";

        # If we haven't JUST registered a hostname, then prefill in the box with ether rqpairs param
        if ( $mode ne "register" ) {
            &HTMLInputText( "ether", 25, $rqpairs{"ether"} );
        }
        else {
            &HTMLInputText( "ether", 25 );
        }

        print "</td><td>\n";

        &HTMLSubmit("Register");
        &HTMLEndForm();

        print "</td>\n";
        $html->EndInnerRow();

        my @nt = (
            [ "ownername",     "Standard" ],
            [ "travelname",    "Travelling" ],
            [ "virtownername", "Virtual" ],
            [ "thinname",      "Thin Client" ]
        );
        my @links = ();
        foreach my $ntref (@nt) {
            my ( $type, $label ) = @$ntref;

            if ( $nametype eq $type ) {
                push( @links, "<b>$label</b>" );
            }
            else {
                push( @links, "<a href=\"?owner=$owner&nametype=$type&ether=$ether\">$label</a>" );
            }
        }

        $html->StartInnerRow();
        print "<td align=center colspan=3>Switch to hostname type: ";
        print join( " | ", @links );
        print "</td>\n";

        $html->EndInnerRow();
    }
}
else {
    $html->StartInnerRow();
    print "<td align=center><b>Owner is at maximum registrations, cannot add any more hosts.</b></td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

print "<p/><p/>\n";

#
# Print out existing registration list
#

$html->StartBlockTable( "Hosts Owned by $owner", 800 );
$html->StartInnerTable( "Host Name", "Ethernet Address", "Options" );

my $ethercnt = 0;
foreach my $host (@hosts) {
    $html->StartInnerRow();
    print "<td><a href=\"view-host.pl?host=$host\">$host</a></td>\n";

    my @ethers = sort( $dhcp->GetEthers($host) );
    $ethercnt += $#ethers + 1;
    print "<td><tt>";
    print $util->FormatEtherList(@ethers);
    print "</td>\n";

    print "<td>";

    print "<a href=\"view-host.pl?host=$host\">View Details</a> | ";
    print "<a href=\"edit-host.pl?mode=view&host=$host\">Edit Host</a> | ";
    print "<a href=\"?mode=delete&owner=$qryowner&host=$host\">Delete Host</a> | ";
    print "<a href=\"http://$host\">Visit Host (http)</a>\n";
    print "</td>\n";

    $html->EndInnerRow();
}

$html->StartInnerRow();
print "<td colspan=3 align=center>\n";
print "To view more details or history about a host, click \"View Details\".\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td colspan=3 align=center>\n";
print "To add/remove additional ethernet addresses or change other host details, click \"Edit Host\".\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();

