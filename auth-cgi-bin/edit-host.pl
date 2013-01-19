#!/usr/bin/perl

# Begin-Doc
# Name: edit-host.pl
# Type: script
# Description: edit host information by single host, detailed
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
require NetMaint::Logging;
require NetMaint::Network;
require NetMaint::Register;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Edit Host Details" );

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs('public') );

$html->PageHeader();

my $hosts    = new NetMaint::Hosts;
my $dhcp     = new NetMaint::DHCP;
my $arp      = new NetMaint::ARP;
my $util     = new NetMaint::Util;
my $dns      = new NetMaint::DNS;
my $log      = new NetMaint::Logging;
my $access   = new NetMaint::Access;
my $network  = new NetMaint::Network;
my $register = new NetMaint::Register;

my $mode   = lc $rqpairs{mode} || "searchform";
my $host   = lc $rqpairs{host};
my $owner  = $rqpairs{owner};
my $type   = lc $rqpairs{type};
my $ip     = $rqpairs{ip};
my $subnet = $rqpairs{subnet};
my $domain = lc $rqpairs{domain};
my $index  = $rqpairs{index};
my $image  = lc $rqpairs{image};

$log->Log();

if ( $mode eq "searchform" ) {
    &DisplaySearchForms();
}
elsif ( $mode eq "search" ) {
    my @hosts = $hosts->SearchByName( $rqpairs{host}, 1000 );

    if ( $#hosts == 0 ) {

        # If we have only one host in the search results, try to immediately
        # refresh to the view page for that host.
        my $host = $hosts[0];

        print "<meta http-equiv=\"Refresh\" content=\"0; URL=";
        print "edit-host.pl?mode=view&host=" . $host . "\">\n";

        print "Found single match for <tt>$host</tt>. Refreshing to ";
        print "<a href=\"?mode=view&host=$host\">edit</a> page.\n";
    }
    elsif ( $#hosts < 0 ) {
        print "<h3>No matching hosts.</h3>\n";
        &DisplaySearchForms();
    }
    else {
        &HTMLStartForm( "edit-host.pl", "GET" );
        &HTMLHidden( "mode", "view" );
        print "Matching hosts: ";
        &HTMLStartSelect( "host", 1 );
        foreach my $hn (@hosts) {
            print "<option>$hn\n";
        }
        &HTMLEndSelect();
        &HTMLSubmit("Edit Host");
        &HTMLEndForm();
    }
}
elsif ( $mode eq "view" )    # display the host, exact match only
{
    my $info = $hosts->GetHostInfo($host);
    if ($info) {

        # search by host name passed, if found, display edit form for that host
        print "<p/><hr/><p/>\n";
        &DisplaySearchForms();
        print "<p/><hr/><p/>\n";

        &DisplayHost($host);
    }
    else {
        print "<h3>Unable to find host <tt>", $html->Encode($host), "</tt>.</h3><p/>\n";
        &DisplaySearchForms();
    }
}
elsif ( $mode eq "deletehost" ) {
    &CheckHostAndDeleteAccess();
    my $verify = $rqpairs{verify};

    if ( $verify eq "yes" ) {
        print "<h3>Deleting host $host</h3>\n";
        $register->DeleteHost($host);
    }
    else {
        print "Are you sure you want to delete all traces of host (";
        print "<tt>", $html->Encode($host), "</tt>)?<br/>\n";

        print "<a href=\"?mode=deletehost&host=$host&verify=yes\">Yes, delete it.</a>\n";
        print "<a href=\"?mode=view&host=$host\">No, don't delete it.</a>\n";
    }
}
elsif ( $mode eq "delether" ) {
    &CheckHostAndEditAccess();

    my $ether = $util->CondenseEther( $rqpairs{ether} );

    print "<h3>Removing ether <tt>", $util->FormatEther($ether), "</tt> from host <tt>$host</tt></h3>\n";
    $dhcp->DeleteHostEther( $host, $ether );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "addether" ) {
    &CheckHostAndEditAccess();

    my $ether = $util->CondenseEther( $rqpairs{ether} );
    if ( !$ether ) {
        $html->ErrorExit("Invalid Ether ($ether)");
    }

    my $eth_check_msg = $util->CheckValidEther($ether);
    if ( $ether && $eth_check_msg ) {
        $html->ErrorExit("$eth_check_msg");
    }

    my $newhost = $dhcp->SearchByEtherExact($ether);
    if ($newhost) {
        $html->ErrorExitRaw( "Ethernet Address ("
                . $util->FormatEther($ether)
                . ") already registered to '"
                . $html->SearchLink_HostEdit($newhost)
                . "'." );
    }

    my $nametype = $access->GetHostNameType($host);

    if ( $nametype eq "ownername" || $nametype eq "travelname" ) {
        my $hinfo = $hosts->GetHostInfo($host);
        my $owner = $hinfo->{owner};
        my $cnt   = $access->GetUsedQuota($owner);
        my $quota = $access->GetRegistrationQuota($owner);

        if ( $cnt >= $quota ) {
            $html->ErrorExit("Owner '$owner' is at or has exceeded registration quota. ($quota)");
        }
    }

    print "<h3>Adding ether <tt>", $util->FormatEther($ether), "</tt> for host <tt>$host</tt></h3>\n";
    $dhcp->AddHostEther( $host, $ether );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "auto_alloc_vmware_ether" ) {
    &CheckHostAndEditAccess();

    my $nametype = $access->GetHostNameType($host);
    my $hinfo    = $hosts->GetHostInfo($host);

    if ( $nametype eq "ownername" || $nametype eq "travelname" ) {
        my $owner = $hinfo->{owner};
        my $cnt   = $access->GetUsedQuota($owner);
        my $quota = $access->GetRegistrationQuota($owner);

        if ( $cnt >= $quota ) {
            $html->ErrorExit("Owner '$owner' is at or has exceeded registration quota. ($quota)");
        }
    }

    my $ether = $dhcp->AutoAllocateVMWareEther($host);

    if ($ether) {
        print "<h3>Allocated ether <tt>", $util->FormatEther($ether), "</tt> for host <tt>$host</tt></h3>\n";

        $hosts->MarkUpdated($host);
    }
    else {
        print "<h3>Failed to allocate an ether for host <tt>$host</tt>.</h3>\n";
    }

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "updatecname" ) {
    &CheckHostAndEditAccess();
    my $target = lc $rqpairs{target};

    my $info = $hosts->GetHostInfo($host);
    if ( !$info || $info->{type} ne "cname" ) {
        $html->ErrorExit("Permission Denied.");
    }

    # replace or add CNAME record for this machine
    if ( $target eq "" ) {
        print "<h3>Deleting cname target for host $host</h3>\n";
        $dns->Delete_CNAME_Record($host);
    }
    else {
        print "<h3>Updating cname target to $target for host $host</h3>\n";
        $dns->Update_CNAME_Record( $host, $target );
    }

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "adminlockhost" ) {
    &CheckHostAndEditAccess();

    if ( !$privs{"sysprog:netdb:adminlock"} ) {
        $html->ErrorExit("Permission Denied.");
    }

    print "<h3>Setting administrative lock for host $host</h3>\n";
    $hosts->SetAdminLock($host);

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "adminunlockhost" ) {
    &CheckHostAndEditAccess();

    if ( !$privs{"sysprog:netdb:adminlock"} ) {
        $html->ErrorExit("Permission Denied.");
    }

    print "<h3>Clearing administrative lock for host $host</h3>\n";
    $hosts->ClearAdminLock($host);

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "updateowner" ) {
    &CheckHostAndEditAccess();
    my $newowner = $rqpairs{owner};

    my $info = $hosts->GetHostInfo($host);
    if ( !$util->UserInfo($newowner) ) {
        $html->ErrorExit("Invalid owner userid.");
    }

    if ( !$privs{"sysprog:netdb:user-on-behalf"} ) {
        $html->ErrorExit("Only users that have the user-on-behalf ability can change host owners.");
    }

    if ( $access->GetHostNameType($host) ne "customname" ) {
        $html->ErrorExit("Owner can only be set for custom named hosts, not owner named hosts.");
    }

    print "<h3>Updating owner to $newowner for host $host</h3>\n";
    $hosts->SetOwner( $host, $newowner );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "updateloc" ) {
    &CheckHostAndEditAccess();
    my $loc = $rqpairs{location};

    my $info = $hosts->GetHostInfo($host);
    if ( $loc eq "" || !$loc ) {
        print "<h3>Clearing location for host $host</h3>\n";
    }
    else {
        print "<h3>Updating location to $loc for host $host</h3>\n";
    }
    $hosts->SetLocation( $host, $loc );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "updatedesc" ) {
    &CheckHostAndEditAccess();
    my $desc = $rqpairs{description};

    if ( $desc eq "" || !$desc ) {
        print "<h3>Clearing description for host $host</h3>\n";
    }
    else {
        print "<h3>Updating description to $desc for host $host</h3>\n";
    }
    $hosts->SetDescription( $host, $desc );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "updatelocdesc" ) {
    &CheckHostAndEditAccess();
    my $loc  = $rqpairs{location};
    my $desc = $rqpairs{description};

    my $info = $hosts->GetHostInfo($host);
    if ( $loc eq "" || !$loc ) {
        print "<h3>Clearing location for host $host</h3>\n";
    }
    else {
        print "<h3>Updating location to $loc for host $host</h3>\n";
    }
    $hosts->SetLocation( $host, $loc );

    if ( $desc eq "" || !$desc ) {
        print "<h3>Clearing description for host $host</h3>\n";
    }
    else {
        print "<h3>Updating description to $desc for host $host</h3>\n";
    }
    $hosts->SetDescription( $host, $desc );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "updateadmincomm" ) {
    &CheckHostAndEditAccess();
    my $desc = $rqpairs{admin_comments};

    if ( !$access->Check( flag => "adminoption", action => "update" ) ) {
        $html->ErrorExit("Permission Denied to add admin comments.");
    }

    my $info = $hosts->GetHostInfo($host);
    if ( $desc eq "" || !$desc ) {
        print "<h3>Clearing admin comments for host $host</h3>\n";
    }
    else {
        print "<h3>Updating admin comments to $desc for host $host</h3>\n";
    }
    $hosts->SetAdminComments( $host, $desc );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}

elsif ( $mode eq "autoaddstatic" ) {
    &CheckHostAndEditAccess();

    if ( !$privs{"sysprog:netdb:static-ip"} ) {
        $html->ErrorExit("Permission Denied to add static addresses.");
    }

    my $sn = $rqpairs{subnet};

    # Strip off any description that was selected
    $sn =~ s/:.*//go;

    if ( !$access->Check( subnet => $sn, action => "update" ) ) {
        $html->ErrorExit("Permission Denied.");
    }

    print "<b>Finding IP for <tt>$host</tt>.</b><p/>\n";

    my $info  = $network->GetAddressesDetail($sn);
    my @addrs = $network->NetworkSort( keys( %{$info} ) );
    if ( $rqpairs{direction} eq "down" ) {
        @addrs = reverse @addrs;
    }

    my $ip;
    while ( !$ip && $addrs[0] ) {
        my $thisaddr = shift @addrs;
        next if ( $info->{$thisaddr}->{host} ne "" );
        next if ( $info->{$thisaddr}->{type} ne "static" );

        $ip = $thisaddr;
    }

    if ( !$ip ) {
        $html->ErrorExit("No available IP address on $sn.");
    }

    print "<b>Attempting to allocate $ip for $host.</b><br/>\n";
    $network->AllocateAddress( $ip, $host );

    print "<b>Attempting to add static PTR record for $host/$ip.</b><br/>\n";
    $dns->Add_Static_PTR( $ip, $host );

    print "<b>Attempting to add static A record for $host/$ip.</b><br/>\n";
    $dns->Add_Static_A( $host, $ip );

    $hosts->MarkUpdated($host);

    $dhcp->TriggerUpdate();

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "addstatic" ) {
    &CheckHostAndEditAccess();

    my $submode = $rqpairs{submode} || "listsubnets";

    if ( !$privs{"sysprog:netdb:static-ip"} ) {
        $html->ErrorExit("Permission Denied to add static addresses.");
    }

    if ( $submode eq "listsubnets" ) {
        my $info = $network->GetSubnets();

        my @subnets = $network->NetworkSort( keys( %{$info} ) );

        print "<b>Adding IP to <tt>$host</tt>.</b><p/>\n";

        &HTMLStartForm( &HTMLScriptURL(), "GET" );
        &HTMLHidden( "mode",    "addstatic" );
        &HTMLHidden( "submode", "listips" );
        &HTMLHidden( "host",    $host );
        print "Available Subnets:<p/>";
        &HTMLStartSelect( "subnet", 20 );
        foreach my $sn (@subnets) {

            if ( $access->Check( subnet => $sn, action => "update" ) ) {
                print "<option value=\"$sn\">$sn - " . "["
                    . $info->{$sn}->{vlan} . "] "
                    . $info->{$sn}->{description} . "\n";
            }
        }
        &HTMLEndSelect();
        print "<p/>";
        &HTMLSubmit("Select");
        &HTMLEndForm();
        print "<p/>\n";

    }
    elsif ( $submode eq "listips" ) {
        my $sn   = $rqpairs{subnet};
        my $host = $rqpairs{host};

        if ( !$access->Check( subnet => $sn, action => "update" ) ) {
            $html->ErrorExit("Permission Denied.");
        }

        print "<b>Adding IP to <tt>$host</tt>.</b><p/>\n";

        my $subnet = shift;

        my $info  = $network->GetAddressesDetail($sn);
        my @addrs = $network->NetworkSort( keys( %{$info} ) );

        &HTMLStartForm( &HTMLScriptURL(), "GET" );
        print "Available static IP Addresses on subnet $sn:<p/>";
        &HTMLHidden( "mode",    "addstatic" );
        &HTMLHidden( "submode", "selectip" );
        &HTMLHidden( "host",    $host );
        &HTMLStartSelect( "address", 20 );
        foreach my $addr (@addrs) {
            my $type = $info->{$addr}->{type};
            my $host = $info->{$addr}->{host};
            next if ( $type ne "static" );
            next if ( $host ne "" );

            print "<option value=\"$addr\">$addr";
        }
        &HTMLEndSelect();
        print "<p/>\n";
        &HTMLSubmit("Select");
        &HTMLEndForm();
        print "<p/>\n";
    }
    elsif ( $submode eq "selectip" ) {
        my $ip   = $rqpairs{address};
        my $host = $rqpairs{host};

        my %info = $network->GetAddressDetail($ip);
        if ( $info{ip} ne $ip ) {
            $html->ErrorExit("Permission Denied - Couldn't look up IP.");
        }
        my $sn = $info{subnet};

        if ( !$access->Check( subnet => $sn, action => "update" ) ) {
            $html->ErrorExit("Permission Denied.");
        }

        if ( $info{host} ne "" ) {
            $html->ErrorExit("Permission Denied - Already Allocated.");
        }

        print "<h3>Attempting to allocate $ip for $host.</h3>\n";
        $network->AllocateAddress( $ip, $host );

        $hosts->MarkUpdated($host);

        $dhcp->TriggerUpdate();

        print "<p/><hr/><p/>\n";
        &DisplaySearchForms();
        print "<p/><hr/><p/>\n";

        &DisplayHost($host);
    }
}
elsif ( $mode eq "enable_static_dns" ) {
    &CheckHostAndEditAccess();

    my $ip = $rqpairs{ip};

    if ( !$privs{"sysprog:netdb:static-dns"} ) {
        $html->ErrorExit("Permission Denied.");
    }

    print "<h3>Attempting to add static PTR record for $host/$ip.</h3><p/>\n";
    $dns->Add_Static_PTR( $ip, $host );

    print "<h3>Attempting to add static A record for $host/$ip.</h3><p/>\n";
    $dns->Add_Static_A( $host, $ip );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "enable_all_static_dns" ) {
    &CheckHostAndEditAccess();

    $dns->BlockUpdates();

    if ( !$privs{"sysprog:netdb:static-dns"} ) {
        $html->ErrorExit("Permission Denied.");
    }

    my @addrs = $network->GetHostAddresses($host);

    foreach my $ip (@addrs) {
        print "<h3>Attempting to add static PTR record for $host/$ip.</h3><p/>\n";
        $dns->Add_Static_PTR( $ip, $host );

        print "<h3>Attempting to add static A record for $host/$ip.</h3><p/>\n";
        $dns->Add_Static_A( $host, $ip );
    }

    $dns->UnblockUpdates();

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "disable_static_dns" ) {
    &CheckHostAndEditAccess();

    my $ip = $rqpairs{ip};

    print "<h3>Removing any PTR records for $host/$ip.</h3><p/>\n";
    $dns->Delete_PTR_ByHostIP( $host, $ip );

    print "<h3>Removing any PTR records for dyn-$host/$ip.</h3><p/>\n";
    $dns->Delete_PTR_ByHostIP( "dyn-$host", $ip );

    print "<h3>Removing any A records for $host/$ip.</h3><p/>\n";
    $dns->Delete_A_ByHostIP( $host, $ip );

    print "<h3>Removing any A records for dyn-$host/$ip.</h3><p/>\n";
    $dns->Delete_A_ByHostIP( "dyn-$host", $ip );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "disable_all_static_dns" ) {
    &CheckHostAndEditAccess();

    $dns->BlockUpdates();

    my @addrs = $network->GetHostAddresses($host);

    foreach my $ip (@addrs) {
        print "<h3>Removing any PTR records for $host/$ip.</h3><p/>\n";
        $dns->Delete_PTR_ByHostIP( $host, $ip );

        print "<h3>Removing any PTR records for dyn-$host/$ip.</h3><p/>\n";
        $dns->Delete_PTR_ByHostIP( "dyn-$host", $ip );

        print "<h3>Removing any A records for $host/$ip.</h3><p/>\n";
        $dns->Delete_A_ByHostIP( $host, $ip );

        print "<h3>Removing any A records for dyn-$host/$ip.</h3><p/>\n";
        $dns->Delete_A_ByHostIP( "dyn-$host", $ip );
    }

    $dns->UnblockUpdates();

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "delstatic" ) {
    &CheckHostAndEditAccess();

    my $ip = $rqpairs{ip};

    print "<h3>Removing any PTR records for $host/$ip.</h3><p/>\n";
    $dns->Delete_PTR_ByHostIP( $host, $ip );

    print "<h3>Removing any A records for $host/$ip.</h3><p/>\n";
    $dns->Delete_A_ByHostIP( $host, $ip );

    print "<h3>Attempting to deallocate $ip from $host.</h3><p/>\n";
    $network->DeallocateAddress( $ip, $host );

    $hosts->MarkUpdated($host);

    $dhcp->TriggerUpdate();

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "dhcpaddoption" ) {
    &CheckHostAndEditAccess();

    my $option = $rqpairs{option};

    if ( $dhcp->IsValidOption($option) ) {
        print "<h3>Adding option <tt>$option</tt> to host <tt>$host</tt>.</h3><p/>\n";
        $dhcp->AddHostOption( $host, $option );
    }
    else {
        print "<h3>Option <tt>$option</tt> is not valid.</h3><p/>\n";
    }

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "dhcpdeloption" ) {
    &CheckHostAndEditAccess();

    my $option = $rqpairs{option};

    print "<h3>Deleting option <tt>$option</tt> from host <tt>$host</tt>.</h3><p/>\n";
    $dhcp->DeleteHostOption( $host, $option );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "adminaddoption" ) {
    &CheckHostAndEditAccess();

    if ( !$access->Check( flag => "adminoption", action => "update" ) ) {
        $html->ErrorExit("Permission Denied to add/remove admin options.");
    }

    my $option = $rqpairs{option};

    if ( $dhcp->IsValidAdminOption($option) ) {
        print "<h3>Adding option <tt>$option</tt> to host <tt>$host</tt>.</h3><p/>\n";
        $dhcp->AddAdminOption( $host, $option );

        if ( $option =~ /DISABLE/o ) {

            $hosts->SendAdminDisableNotice($host);

            my $info = $hosts->GetHostInfo($host);
            print "<h3>System disabled email sent to '", $info->{owner}, "'.</h3><p/>\n";
        }
    }
    else {
        print "<h3>Option <tt>$option</tt> is not valid.</h3><p/>\n";
    }

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}
elsif ( $mode eq "admindeloption" ) {
    &CheckHostAndEditAccess();

    if ( !$access->Check( flag => "adminoption", action => "update" ) ) {
        $html->ErrorExit("Permission Denied to add/remove admin options.");
    }

    my $option = $rqpairs{option};

    print "<h3>Deleting option <tt>$option</tt> from host <tt>$host</tt>.</h3><p/>\n";
    $dhcp->DeleteAdminOption( $host, $option );

    $hosts->MarkUpdated($host);

    print "<p/><hr/><p/>\n";
    &DisplaySearchForms();
    print "<p/><hr/><p/>\n";

    &DisplayHost($host);
}

# Begin-Doc
# Name: CheckHostAndEditAccess
# Description: check if host exists and if user has rights to edit it
# End-Doc
sub CheckHostAndEditAccess {
    if ( !$host ) {
        $html->ErrorExit("No host specified.");
    }

    my $info = $hosts->GetHostInfo($host);
    if ( !$info ) {
        $html->ErrorExit( "Host (" . $html->Encode($host) . ") not found." );
    }

    my $edit_ok   = $access->CheckHostEditAccess( host => $host, action => "update" );
    my $delete_ok = $access->CheckHostEditAccess( host => $host, action => "delete" );

    if ( !$edit_ok && !$delete_ok ) {
        $html->ErrorExit( "Access denied to edit host (" . $html->Encode($host) . ")" );
    }
}

# Begin-Doc
# Name: CheckHostAndDeleteAccess
# Description: check if host exists and if user has rights to delet it
# End-Doc
sub CheckHostAndDeleteAccess {
    if ( !$host ) {
        $html->ErrorExit("No host specified.");
    }

    my $info = $hosts->GetHostInfo($host);
    if ( !$info ) {
        $html->ErrorExit( "Host (" . $html->Encode($host) . ") not found." );
    }

    if ( !$access->CheckHostEditAccess( host => $host, action => "delete" ) ) {
        $html->ErrorExit( "Access denied to delete host (" . $html->Encode($host) . ")" );
    }
}

# Begin-Doc
# Name: DisplayHost
# Description: displays host with various forms and links for performing edit operations
# Syntax: &DisplayHost($host);
# End-Doc
sub DisplayHost {
    my $host = shift;
    my $info;

    print <<AUTOSUGGEST;
<script type="text/javascript" src="/~jstools/autosuggest/js/autosuggest.js"></script>
<link rel="stylesheet" href="/~jstools/autosuggest/css/autosuggest.css" type="text/css" media="screen" charset="utf-8" />
AUTOSUGGEST

    print "<p/>\n";
    print "<a href=\"view-host.pl?host=$host\">";
    print "View host details for $host</a>\n";
    print "<p/>\n";

    print "<p/>\n";
    print "<a target=_history href=\"view-host-history.pl?mode=view&host=$host\">";
    print "View history for $host</a><p/>\n";

    &CheckHostAndEditAccess();

    my $info = $hosts->GetHostInfo($host);
    if ( !$info ) {
        $html->ErrorExit( "Host (", $html->Encode($host), ") not found." );
    }

    print "<a href=\"?mode=view&host=$host\">Refresh Display</a><p/>\n";

    print "<p/>\n";
    $html->Display_HostInfo($info);

    print "<p/>\n";
    $html->Display_Person(
        title  => "Owner Details",
        userid => $info->{owner}
    );

    if (   $access->GetHostNameType($host) eq "customname"
        && $privs{"sysprog:netdb:user-on-behalf"} )
    {
        print "<p/>\n";
        $html->StartBlockTable( "Host Owner Update", 600 );
        $html->StartInnerTable();

        $html->StartInnerRow();
        print "<td><b>Owner UserID:</b></td><td colspan=2><tt>", $info->{owner}, "</tt></td>\n";
        $html->EndInnerRow();

        $html->StartInnerRow();
        print "<td>";
        print "<b>New Owner UserID:</b></td><td>";
        &HTMLStartForm( &HTMLScriptURL, "GET" );
        &HTMLHidden( "mode", "updateowner" );
        &HTMLHidden( "host", $host );
        &HTMLInputText( "owner", 50 );
        print "</td><td>";
        &HTMLSubmit("Update");
        &HTMLEndForm();
        print "</td>\n";
        $html->EndInnerRow();
        $html->EndInnerTable();
        $html->EndBlockTable();

    }

    print "<p/>\n";
    $html->StartBlockTable( "Location and Description of Host", 600 );
    $html->StartInnerTable();

    if ( $info->{location} ) {
        $html->StartInnerRow();
        print "<td><b>Location:</b></td><td><tt>", $info->{location}, "</td>\n";
        print "<td>\n";
        print "<a href=\"?mode=updateloc&host=$host&location=\">Clear</a>\n";
        print "</td>\n";
        $html->EndInnerRow();
    }
    else {
        $html->StartInnerRow();
        print "<td><b>Location:</b></td><td>No location set.</td><td></td>\n";
        $html->EndInnerRow();
    }

    if ( $info->{description} ) {
        $html->StartInnerRow();
        print "<td><b>Description:</b></td><td><tt>", $info->{description}, "</td>\n";
        print "<td>\n";
        print "<a href=\"?mode=updatedesc&host=$host&description=\">Clear</a>\n";
        print "</td>\n";
        $html->EndInnerRow();
    }
    else {
        $html->StartInnerRow();
        print "<td><b>Description:</b></td><td>No description set.</td><td></td>\n";
        $html->EndInnerRow();
    }

    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "mode", "updatelocdesc" );
    &HTMLHidden( "host", $host );

    $html->StartInnerRow();
    print "<td>";
    print "<b>New Location:</b></td><td colspan=2>";
    &HTMLInputText( "location", 50, $info->{location} );
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>";
    print "<b>New Description:</b></td><td colspan=2>";
    &HTMLInputText( "description", 50, $info->{description} );
    print "</td>";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td colspan=3 align=center>\n";
    &HTMLSubmit("Update");
    &HTMLEndForm();
    print "</td>\n";
    $html->EndInnerRow();
    $html->EndInnerTable();
    $html->EndBlockTable();

    print "<p/>\n";
    $html->StartBlockTable( "Admin Comments for Host", 600 );
    $html->StartInnerTable();

    if ( $info->{admin_comments} ) {
        $html->StartInnerRow();
        print "<td><b>Admin Comments:</b></td><td><tt>", $info->{admin_comments}, "</td>\n";
        print "<td>\n";
        print "<a href=\"?mode=updateadmincomm&host=$host&admin_comments=\">Clear</a>\n";
        print "</td>\n";
        $html->EndInnerRow();
    }
    else {
        $html->StartInnerRow();
        print "<td><b>Admin Comments:</b></td><td colspan=2>No admin comments set.</td>\n";
        $html->EndInnerRow();
    }

    $html->StartInnerRow();
    print "<td>";
    print "<b>New Admin Comments:</b></td><td>";
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "mode", "updateadmincomm" );
    &HTMLHidden( "host", $host );
    &HTMLInputText( "admin_comments", 50 );
    print "</td><td>";
    &HTMLSubmit("Update");
    &HTMLEndForm();
    print "</td>\n";
    $html->EndInnerRow();
    $html->EndInnerTable();
    $html->EndBlockTable();

    my $hosttype = $info->{type};
    my $owner    = $info->{owner};
    my $nametype = $access->GetHostNameType($host);

    my %dhcp_options  = $dhcp->GetOptionInfo();
    my %admin_options = $dhcp->GetAdminOptionInfo();

    if ( $hosttype ne "cname" ) {
        my @options = $dhcp->GetHostOptions($host);

        print "<p/>\n";
        $html->StartBlockTable( "DHCP Host Options", 600 );
        $html->StartInnerTable();
        $html->StartInnerRow();
        print "<td align=center>";
        print "Extra DHCP options can be added to the host when specifically\n";
        print "required. Regular desktop systems should not require any ";
        print "special options. Do not use this option unless directed by IT.\n";
        $html->EndInnerRow();
        my %seen = ();

        foreach my $option (@options) {
            my $opt = $option->{option};

            $html->StartInnerRow();
            print "<td align=center>";
            if ( $opt =~ /^#\s*([A-Z0-9-]+)\s*$/ ) {
                $seen{$1} = 1;
                print $1, ": ", $dhcp_options{$1}, "\n";
                print " - ";
                print "<a href=\"?mode=dhcpdeloption&host=$host&option=$1\">";
                print "Delete Option</a>\n";
            }
            else {
                print $html->Encode($opt), "\n";
                print " - ";
                print "<a href=\"?mode=dhcpdeloption&host=$host&option=$opt\">";
                print "Delete Option</a>\n";
            }

            print "</td>\n";
            $html->EndInnerRow();
        }

        $html->StartInnerRow();
        print "<td align=center colspan=2>";
        &HTMLStartForm( &HTMLScriptURL, "GET" );
        &HTMLHidden( "mode", "dhcpaddoption" );
        &HTMLHidden( "host", $host );
        &HTMLStartSelect( "option", 1 );
        print "<option value=\"\">\n";
        foreach my $option ( sort( keys(%dhcp_options) ) ) {
            next if ( $seen{$option} );
            print "<option value=$option>";
            print $option, ": ", $dhcp_options{$option}, "\n";
        }
        &HTMLEndSelect();
        &HTMLSubmit("Add Additional Option");
        &HTMLEndForm();
        $html->EndInnerRow();
        $html->EndInnerTable();
        $html->EndBlockTable();

        if ( $access->Check( flag => "adminoption", action => "update" ) ) {

            my @options = $dhcp->GetAdminOptions($host);

            print "<p/>\n";
            $html->StartBlockTable( "Admin Host Options", 600 );
            $html->StartInnerTable();
            $html->StartInnerRow();
            print "<td align=center>";
            print "Extra admin options can be added to the host when specifically\n";
            print "required. Regular desktop systems should not require any ";
            print "special options. This functionality is limited to ";
            print "EngOps staff. Be sure and also lock the host if you are disabling it.\n";
            $html->EndInnerRow();
            my %seen = ();

            foreach my $option (@options) {
                my $opt = $option->{option};

                $html->StartInnerRow();
                print "<td align=center>";
                if ( $opt =~ /^#\s*([A-Z0-9-_]+)\s*$/ ) {
                    $seen{$1} = 1;
                    print $1, ": ", $admin_options{$1}, "\n";
                    print " - ";
                    print "<a href=\"?mode=admindeloption&host=$host&option=$1\">";
                    print "Delete Option</a>\n";
                }
                else {
                    print $html->Encode($opt), "\n";
                    print " - ";
                    print "<a href=\"?mode=admindeloption&host=$host&option=$opt\">";
                    print "Delete Option</a>\n";
                }

                print "</td>\n";
                $html->EndInnerRow();
            }

            $html->StartInnerRow();
            print "<td align=center colspan=2>";
            &HTMLStartForm( &HTMLScriptURL, "GET" );
            &HTMLHidden( "mode", "adminaddoption" );
            &HTMLHidden( "host", $host );
            &HTMLStartSelect( "option", 1 );
            print "<option value=\"\">\n";
            foreach my $option ( sort( keys(%admin_options) ) ) {
                next if ( $seen{$option} );
                print "<option value=$option>";
                print $option, ": ", $admin_options{$option}, "\n";
            }
            &HTMLEndSelect();
            &HTMLSubmit("Add Additional Option");
            &HTMLEndForm();
            $html->EndInnerRow();
            $html->EndInnerTable();
            $html->EndBlockTable();

        }

        #
        # Need to get a count of how many ethernet addresses this owner
        # has registered so we can enforce quota
        #

        print "\n<p/>\n";
        $html->StartBlockTable( "Registered Ethernet Addresses", 600 );
        $html->StartInnerTable();

        my @ethers = $dhcp->GetEthers($host);
        foreach my $ether (@ethers) {
            $html->StartInnerRow();
            print "<td align=center>", $util->FormatEther($ether);
            print " - <a href=\"?mode=delether&host=$host&ether=$ether\">Delete</a></td>\n";
            $html->EndInnerRow();
        }

        my $allow_more_eth = 1;
        if ( ( $nametype eq "ownername" || $nametype eq "travelname" )
            && $hosttype eq "desktop" )
        {
            my $curreg = $access->GetUsedQuota($owner);
            my $quota  = $access->GetRegistrationQuota($owner);
            if ( $curreg >= $quota ) { $allow_more_eth = 0; }
        }
        if ($allow_more_eth) {
            $html->StartInnerRow();
            print "<td align=center>";
            &HTMLStartForm( &HTMLScriptURL, "GET" );
            &HTMLHidden( "mode", "addether" );
            &HTMLHidden( "host", $host );
            &HTMLInputText( "ether", 15 );
            print " ";
            &HTMLSubmit("Add New Address");
            print "</td>";
            &HTMLEndForm();
            $html->EndInnerRow();

            $html->StartInnerRow();

            print "<td align=center><a href=\"?mode=auto_alloc_vmware_ether&host=$host\">Automatically Allocate ";
            print "VMWare Ethernet Address</a></td>\n";

            $html->EndInnerRow();
        }
        else {
            $html->StartInnerRow();
            print "<td colspan=2 align=center>Owner has maximum ethernet addresses registered.</td>\n";
            $html->EndInnerRow();
        }

        $html->EndInnerTable();
        $html->EndBlockTable();

        print "\n<p/>\n";
        $html->StartBlockTable( "Allocated IP Addresses", 600 );
        $html->StartInnerTable();

        my @addrs = $network->GetHostAddresses($host);
        my $ipcnt = 0;
        foreach my $ip ( $network->NetworkSort(@addrs) ) {
            $ipcnt++;
            $html->StartInnerRow();
            print "<td>$ip";

            print "<td><a href=\"?mode=delstatic&host=$host&ip=$ip\">Delete</a>\n";

            if ( $privs{"sysprog:netdb:static-dns"} ) {
                print " - <a href=\"?mode=enable_static_dns&host=$host&ip=$ip\">";
                print "Enable Static DNS</a> ";
            }

            print " - <a href=\"?mode=disable_static_dns&host=$host&ip=$ip\">";
            print "Disable Static DNS</a> ";
            $html->EndInnerRow();
        }

        if ( $ipcnt == 0 ) {
            $html->StartInnerRow();
            print "<td align=center colspan=2>No IP addresses have been staticly assigned to this host.\n";
            $html->EndInnerRow();
        }

        if ( $privs{"sysprog:netdb:static-ip"} ) {
            $html->StartInnerRow();
            print "<td align=center colspan=2>\n";

            if ( $ipcnt > 0 ) {
                print "<a href=\"?mode=enable_all_static_dns&host=$host\">";
                print "Enable All Static DNS</a> - ";
                print "<a href=\"?mode=disable_all_static_dns&host=$host\">";
                print "Disable All Static DNS</a> - ";
            }
            print "<a href=\"?mode=addstatic&host=$host\">Allocate Additional Static Address</a></td>\n";
            $html->EndInnerRow();

            my @sn     = ();
            my $sninfo = $network->GetSubnets();
            foreach my $sn ( keys(%$sninfo) ) {
                my $desc = $sninfo->{$sn}->{description};
                next
                    if ( $desc !~ /System/
                    && $desc !~ /Server/
                    && $desc !~ /SRV/ );
                push( @sn, $sn );
            }

            $html->StartInnerRow();
            &HTMLStartForm( &HTMLScriptURL, "GET" );
            &HTMLHidden( "mode", "autoaddstatic" );
            &HTMLHidden( "host", $host );
            print "<td align=center colspan=2>";
            &HTMLSubmit("Auto");
            print " ";
            &HTMLStartSelect( "direction", 1 );
            print "<option value=up selected>Ascending\n";
            print "<option value=down>Descending\n";
            &HTMLEndSelect();
            print "<input type=text id=subnet name=subnet size=50 value=\"\">\n";
            print "<br>Enter part of a subnet address, name, or vlan to bring\n";
            print "up suggestion list. (examples: SRV, ISCSI, HPC, LB)\n";
            &HTMLEndForm();

            print <<EOF;

<script type="text/javascript">

var subnet_as_options = {

    /* had to add the cachets stuff cause IE insisted on caching the search results every time */
    script: function (input) { return "/auth-cgi-bin/cgiwrap/netdb/ajax-subnets.pl?max=15&q="+input+"&cachets=" + new Date().getTime(); },
    json:true,
    shownoresults:true,
    noresults:"No matching subnet!",
    minchars:2,
    cache:false,
    delay:40,
    timeout:15000,
    maxentries:15
};
var as_json = new bsn.AutoSuggest('subnet', subnet_as_options);

</script>
EOF

            if ( $hosttype eq "network" ) {
                print "<br/>WDS VLAN: ";
                print "<a href=\"?mode=autoaddstatic&host=$host&subnet=10.2.7.0/26\">303</a> | ";
                print "<a href=\"?mode=autoaddstatic&host=$host&subnet=10.2.7.64/26\">304</a> | ";
                print "<a href=\"?mode=autoaddstatic&host=$host&subnet=10.2.7.128/26\">305</a> | ";
                print "<a href=\"?mode=autoaddstatic&host=$host&subnet=10.2.7.192/26\">306</a> ";
            }

            print "</td>\n";
            $html->EndInnerRow();

            $html->StartInnerRow();
            print
                "<td align=center colspan=2>If a host is using DHCP, allocating a static IP will insure that it gets the same IP every time it renews.</a>\n";
            print
                "Enabling static DNS should only be used if the host will not be using DHCP, and will register the host in DNS such that it cannot be mobile. This should only be needed for network devices, servers, and anything else not using DHCP.</a></td>\n";
            $html->EndInnerRow();
        }
        $html->EndInnerTable();
        $html->EndBlockTable();

        print "\n<p/>\n";

        my @static_a   = $dns->Get_Static_A_Records($host);
        my @static_ptr = $dns->Get_Static_PTR_Records($host);

        if ( $ipcnt != 0 || $#static_a >= 0 || $#static_ptr >= 0 ) {
            $html->StartBlockTable( "Staticly Assigned DNS Records", 600 );
            if ( $#static_a < 0 && $#static_ptr < 0 ) {
                $html->StartInnerTable();
                $html->StartInnerRow();
                print "<td align=center>This host has no staticly assigned DNS records.</td>\n";
                $html->EndInnerRow();
                $html->EndInnerTable();
            }
            else {
                $html->StartInnerTable( "Name", "Target" );

                foreach my $entry ( $dns->Get_Static_A_Records($host) ) {
                    $html->StartInnerRow();
                    print "<td>", $entry->{name},    "</td>\n";
                    print "<td>", $entry->{address}, "</td>\n";
                    $html->EndInnerRow();
                }

                foreach my $entry ( $dns->Get_Static_PTR_Records($host) ) {
                    $html->StartInnerRow();
                    print "<td>", $entry->{name}, " [", $util->ARPAToIP( $entry->{name} ), "]", "</td>\n";
                    print "<td>", $entry->{address}, "</td>\n";
                    $html->EndInnerRow();
                }

                $html->EndInnerTable();
            }
            $html->EndBlockTable();
        }
    }

    if ( $hosttype eq "cname" ) {
        print "\n<p/>\n";
        $html->StartBlockTable( "Canonical Name Information", 600 );
        $html->StartInnerTable();

        my ($entry) = $dns->Get_CNAME_Records($host);

        if ($entry) {
            $html->StartInnerRow();
            print "<td><b>Target:</b></td><td><tt>", $entry->{address}, "</td>\n";
            print "<td>\n";
            print "<a href=\"?mode=updatecname&host=$host\">Delete</a>\n";
            print "</td>\n";
            $html->EndInnerRow();
        }
        else {
            $html->StartInnerRow();
            print "<td><b>Target:</b></td><td>No target defined.</td><td></td>\n";
            $html->EndInnerRow();
        }

        $html->StartInnerRow();
        print "<td>";
        print "<b>New Target:</b></td><td>";
        &HTMLStartForm( &HTMLScriptURL, "GET" );
        &HTMLHidden( "mode", "updatecname" );
        &HTMLHidden( "host", $host );
        &HTMLInputText( "target", 25 );
        print "</td><td>";
        &HTMLSubmit("Update");
        &HTMLEndForm();
        print "</td>\n";
        $html->EndInnerRow();
        $html->EndInnerTable();
        $html->EndBlockTable();
    }

    print "\n<p/>\n";

    my $info = $hosts->GetHostInfo($host);

    if ( $info && $info->{adminlock} ) {
        $html->StartBlockTable( "Administrative Lock Status", 600 );
        $html->StartInnerTable();
        $html->StartInnerRow();
        print "<td align=center><b>Host is administratively locked. Only administrators can edit.</b></td>\n";
        if ( $privs{"sysprog:netdb:adminlock"} ) {
            print "<td>\n";
            print "<a href=\"?mode=adminunlockhost&host=$host\">Unlock Host</a>\n";
            print "</td>\n";
        }
        $html->EndInnerRow();
        $html->EndInnerTable();
        $html->EndBlockTable();
    }
    else {
        if ( $privs{"sysprog:netdb:adminlock"} ) {
            $html->StartBlockTable( "Administrative Lock Status", 600 );
            $html->StartInnerTable();
            $html->StartInnerRow();
            print "<td align=center>Host is unlocked and can be edited.</td>\n";
            print "<td>\n";
            print "<a href=\"?mode=adminlockhost&host=$host\">Lock Host</a>\n";
            print "</td>\n";
            $html->EndInnerRow();
            $html->EndInnerTable();
            $html->EndBlockTable();
        }
    }

    print "<p/>\n";
    print "<a href=\"?mode=deletehost&host=$host\">Delete this Host</a>";
    print " | ";
    print "<a href=\"rename-host.pl?oldhost=$host\">Rename this Host</a>\n";

    my $nametype = $access->GetHostNameType($host);
    my $type     = $info->{type};

    print " | ";
    print
        "<a href=\"rename-host.pl?mode=hostname&nametype=$nametype&type=$type&oldhost=$host\">Fast Rename this Host</a>\n";
}

# Begin-Doc
# Name: DisplaySearchForms
# Type: function
# Description: output the hostname search form
# End-Doc
sub DisplaySearchForms {
    my $host = $rqpairs{"host"} || "";
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    print "Search for host: ";
    &HTMLHidden( "mode", "search" );
    &HTMLInputText( "host", 30, $host );
    print " ";
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";

    print "<a href=\"create-host.pl\">Create a new host</a>\n";
}

$html->PageFooter();

