#!/usr/bin/perl

# Begin-Doc
# Name: create-host.pl
# Type: script
# Description: Create Host information by single host, detailed
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

my $html = new NetMaint::HTML( title => "Create New Host" );

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

my $mode     = lc $rqpairs{mode} || "hosttype";
my $host     = lc( $rqpairs{host} );
my $owner    = lc( $rqpairs{owner} ) || $ENV{REMOTE_USER};
my $type     = $rqpairs{type};
my $ip       = $rqpairs{ip};
my $subnet   = $rqpairs{subnet};
my $domain   = lc( $rqpairs{domain} );
my $index    = $rqpairs{index};
my $image    = lc( $rqpairs{image} );
my $nametype = $rqpairs{nametype};
my $hostname = lc $rqpairs{hostname};
my $ether    = $rqpairs{ether};
my $target   = $rqpairs{target};

$log->Log();

# attempt to create new host by parms passed
# need modes for selecting type, domain, and hostname

my %host_types = (
    "guest"   => "Guest/Sponsored Host",
    "device" => "Device",
    "cname"   => "Canonical Name (CNAME)",
    "server"  => "Server",
);

my %name_types = (
    "ownername"     => "Owner Host Names [s##owner]",
    "customname"    => "Custom Host Name [*.domain]",
);

my %privs = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );
if ( !$privs{"sysprog:netdb:user-on-behalf"} ) {

    # if we don't have impersonate privilege, force owner to authenticated userid regardless of type of registration
    $owner = $ENV{REMOTE_USER};
}

if ( $mode eq "hosttype" ) {

    # first thing we need is to determine what type of host to create
    # print out list

    print "<table border=0>\n";
    print "<tr><td>\n";

    print "<h3>Type of Host to Register:</h3>\n";

    print "<ul>\n";
    my $cnt = 0;
    foreach my $type ( sort( keys(%host_types) ) ) {
        if ( $access->Check( type => $type, action => "insert" ) ) {
            print "<li><a href=\"?mode=nametype&type=$type\">", $host_types{$type}, " [$type]</a>\n";
            $cnt++;

            # Quick links, also display allowed name types
            print "<font size=-1>\n";
            print "<ul>\n";

            my $cnt = 0;
            foreach my $ntype ( sort( keys(%name_types) ) ) {

                next if ( !$hosts->CheckValidNameType( type => $type, nametype => $ntype ) );

                if ($access->Check(
                        type   => $type,
                        flag   => $ntype,
                        action => "insert"
                    )
                    )
                {

                    if ($privs{"sysprog:netdb:user-on-behalf"}
                        && (   $ntype eq "ownername" )
                        )
                    {
                        print "<li><a href=\"?mode=${ntype}&type=$type&nametype=$ntype\">";
                        print $name_types{$ntype}, " [$ntype]</a>\n";
                        $cnt++;
                    }
                    else {
                        print "<li><a href=\"?mode=hostname&type=$type&nametype=$ntype\">";
                        print $name_types{$ntype}, " [$ntype]</a>\n";
                        $cnt++;
                    }

                }

            }
            print "</ul>\n";
            print "</font>\n";
            print "<p/>\n";

        }
    }
    print "</ul>\n";

    print "</td></tr></table>\n";

    if ( $cnt == 0 ) {
        print "<h3>You are not authorized to register any hosts.</h3>\n";
    }
}
elsif ( $mode eq "nametype" ) {
    print "<h3>Naming style of <tt>$type</tt> host to Register:</h3>\n";

    print "<ul>\n";
    my $cnt = 0;
    foreach my $ntype ( sort( keys(%name_types) ) ) {
        next if ( !$hosts->CheckValidNameType( type => $type, nametype => $ntype ) );

        if ($access->Check(
                type   => $type,
                flag   => $ntype,
                action => "insert"
            )
            )
        {
            if ($privs{"sysprog:netdb:user-on-behalf"}
                && (   $ntype eq "ownername"
                    )
                )
            {
                print "<li><a href=\"?mode=${ntype}&type=$type&nametype=$ntype\">";
                print $name_types{$ntype}, " [$ntype]</a>\n";
                $cnt++;
            }
            else {
                print "<li><a href=\"?mode=hostname&type=$type&nametype=$ntype\">";
                print $name_types{$ntype}, " [$ntype]</a>\n";
                $cnt++;
            }
        }
    }
    print "</ul>\n";

    if ( $cnt == 0 ) {
        print "<h3>No naming styles available.</h3>\n";
    }

}
elsif ( $mode eq "hostname" ) {

    if ( $nametype eq "ownername" ) {
        if ( length($owner) > 11 ) {
            $html->ErrorExit(
                "Owner named devices limited to 11 character owner names. Contact EngOps to make a custom registration.");
        }
    }

    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "mode",     "create" );
    &HTMLHidden( "nametype", $nametype );
    &HTMLHidden( "type",     $type );

    if ( $nametype eq "ownername" ) {
        print "s";
    }

    if ($nametype eq "ownername" )
    {
        &SimpleHostIndexMenu();
        print $owner;

        print ".";
        &SimpleDomainMenu();

        &HTMLHidden( "owner", $owner );
    }
    elsif ( $nametype eq "customname" ) {
        &HTMLInputText( "hostname", 30 );
        print ".";
        &SimpleDomainMenu();

        print "<p/>Owner: ";
        if ( $privs{"sysprog:netdb:user-on-behalf"} ) {
            &HTMLInputText( "owner", 10, $hosts->GetDefaultOwner( type => $type, nametype => $nametype ) );
        }
        else {
            print $owner;
            &HTMLHidden( "owner", $owner );
        }

    }

    print "<p/>\n";
    if ( $type eq "cname" ) {
        print "  Optional Target: ";
        &HTMLInputText( "target", 40 );
    }
    else {
        print "  Optional Ethernet Address: ";
        &HTMLInputText( "ether", 20 );
        print "<br/>";
        &HTMLCheckbox( "auto_alloc_vmware_ether", 0 );
        print "Automatically allocate VMWare Ethernet Address.\n";
    }
    print "<p/>\n";

    &SimpleDHCPOptionMenu();

    &HTMLSubmit("Create");
    &HTMLEndForm();
    print "<p/>\n";

}
elsif ($mode eq "ownername" )
{
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "mode",     "hostname" );
    &HTMLHidden( "nametype", $nametype );
    &HTMLHidden( "type",     $type );

    my $defowner = $hosts->GetDefaultOwner( type => $type, nametype => $nametype );

    print "Owner: ";
    if ( $privs{"sysprog:netdb:user-on-behalf"} ) {
        &HTMLInputText( "owner", 10, $defowner );
    }
    else {
        print $ENV{REMOTE_USER};
        &HTMLHidden( "owner", $ENV{REMOTE_USER} );
    }
    print "<p/>\n";

    &HTMLSubmit("Create");
    &HTMLEndForm();
    print "<p/>\n";
}
elsif ( $mode eq "create" ) {
    my $host;

    if ( $owner && !$util->UserInfo($owner) ) {
        $html->ErrorExit("Invalid owner, userid does not exist.");
    }

    if ( $index eq "##" ) {
        my @free = $hosts->GetFreeIndexes( owner => $owner, nametype => $nametype );
        my $picked = shift @free;

        if ( !$picked ) {
            $html->ErrorExit("Unable to determine next available index.");
        }
        $index = $picked;
    }
    $index = int($index);

    my $shorthost = $hostname;
    $shorthost =~ s/\..*//gio;
    my @old_hosts = $hosts->SearchByName($shorthost);
    foreach my $old_host (@old_hosts) {
        my $shost = $old_host;
        $shost =~ s/\..*//gio;
        if ( $shost eq $shorthost ) {
            print "<h3>Short hostname might conflict with '<tt>";
            print $html->SearchLink_Host($old_host);
            print "</tt>'.</h3>\n";
        }
    }

    my $eth_check_msg = $util->CheckValidEther($ether);
    if ( $ether && $eth_check_msg ) {
        $html->ErrorExit("$eth_check_msg");
    }

    my $eth_host_assigned = $dhcp->SearchByEtherExact($ether);
    if ( $ether && $eth_host_assigned ) {
        $html->ErrorExitRaw( "Ethernet address already assigned to '"
                . $html->SearchLink_HostEdit($eth_host_assigned)
                . "', host not created." );
    }

    if ( $type eq "guest" ) {
        if ( $nametype ne "ownername" ) {
            $html->ErrorExit("Guest machines must be named for the sponsor/owner.");
        }

        if ( $domain !~ /guest/ ) {
            $html->ErrorExit("Guest machines must be in the guest subdomain.");
        }
    }

    my $host;

    if ( $nametype eq "ownername" ) {
        $host = sprintf( "s%.2d%s.%s", $index, $owner, $domain );
    }
    elsif ( $nametype eq "customname" ) {
        $host = sprintf( "%s.%s", $hostname, $domain );
    }

    if ( !$host ) {
        $html->ErrorExit("Unable to generate hostname from parameters.");
    }

    my $foundtype = $access->GetHostNameType($host);
    if ( $foundtype ne $nametype ) {
        $html->ErrorExit("Hostname ($host) Invalid - request type ($nametype), determined type ($foundtype)");
    }

    if ( $nametype eq "ownername" ) {
        if ( !$privs{"sysprog:netdb:user-on-behalf"} ) {
            if ( $owner ne $ENV{REMOTE_USER} ) {
                $html->ErrorExit("Permission Denied (Owner mismatch).");
            }
        }

        if ( $access->GetHostNameType($host) ne "ownername" ) {
            $html->ErrorExit("Hostname ($host) Invalid");
        }

        my @existing_hosts = $hosts->SearchByOwnerExact($owner);
        foreach my $existing_host (@existing_hosts) {
            if ( $existing_host =~ /^r(\d\d)/o ) {
                if ( $index == $1 ) {
                    $html->ErrorExit("Host index $index already used by $existing_host.");
                }
            }
        }
    }

    my $err = $hosts->CheckNameLength( host => $host );
    if ($err) {
        $html->ErrorExit($err);
    }

    if ( $ether && length( $util->CondenseEther($ether) ) != 12 ) {
        $html->ErrorExit("Ethernet address ($ether) invalid.");
    }

    if (!$access->Check(
            flag   => $nametype,
            domain => $domain,
            type   => $type,
            action => "insert"
        )
        )
    {
        $html->ErrorExit("Permission Denied (Insert).");
    }

    my $info = $hosts->GetHostInfo($host);
    if ($info) {
        $html->ErrorExitRaw( "Hostname <tt>" . $html->SearchLink_HostEdit($host) . "</tt> already registered." );
    }

    my $cnt   = $access->GetUsedQuota($owner);
    my $quota = $access->GetRegistrationQuota($owner);

    if ( $cnt >= $quota ) {
        $html->ErrorExit("Owner '$owner' is at or has exceeded registration quota. ($quota)");
    }

    print "<h3>Attempting to create host $host.</h3>\n";

    my $res = $hosts->CreateHost(
        host   => $host,
        domain => $domain,
        owner  => $owner,
        type   => $type
    );
    if ($res) {
        $html->ErrorExit("Failed to register host: $res");
    }

    print "<h3>Host registered successfully!</h3><p/>\n";

    if ( $ether && $type ne "cname" ) {
        print "<h3>Attempting to register ethernet address $ether for host $host.</h3>\n";

        my $cether = $util->CondenseEther($ether);

        print "\n";
        $dhcp->AddHostEther( $host, $ether );
    }

    if ( $target && $type eq "cname" ) {
        print "<h3>Attempting to register cname target $target for host $host.</h3>\n";

        print "\n";
        $dns->Update_CNAME_Record( $host, $target );
    }

    if ( $rqpairs{"auto_alloc_vmware_ether"} eq "on" ) {
        print "<h3>Attempting to automatically allocate a VMWare Ethernet Address.</h3>\n";

        my $ether = $dhcp->AutoAllocateVMWareEther($host);
        if ($ether) {
            print "<h3>Allocated: ", $util->FormatEther($ether), "<h3>\n";
        }
        else {
            print "<h3>Unable to allocate a VMWare Ethernet Address.</h3>\n";
        }

        print "\n";
    }

    if ( $rqpairs{"dhcpoptions"} ) {
        my @options = split( /\s+/, $rqpairs{"dhcpoptions"} );
        foreach my $option (@options) {
            if ( $dhcp->IsValidOption($option) ) {
                print "<h3>Adding dhcp option <tt>$option</tt> to host <tt>$host</tt>.</h3>\n";
                $dhcp->AddHostOption( $host, $option );
            }
            else {
                print "<h3>Skipping invalid dhcp option <tt>$option</tt> to host <tt>$host</tt>.</h3>\n";
            }
        }
    }

    print "<p/>\n";
    print "<a href=\"edit-host.pl?mode=view&host=$host\">Edit Host Details</a><p/>\n";
}

$html->PageFooter();

# Begin-Doc
# Name: SimpleDomainMenu
# Description: print out menu of selectable domains
# End-Doc
sub SimpleDomainMenu {

    my @domains = ();

    my %domains = $dns->GetDomains();
    foreach my $domain ( sort( keys(%domains) ) ) {

        next if ( !$hosts->CheckValidNameTypeDomain( type => $type, nametype => $nametype, domain => $domain ) );

        if ($access->Check(
                type   => $type,
                flag   => $nametype,
                domain => $domain,
                action => "insert"
            )
            )
        {
            push( @domains, $domain );
        }
    }

    my $prefdomain;

    if ( scalar(@domains) > 1 ) {
        &HTMLStartSelect( "domain", 1 );
        foreach my $domain (@domains) {
            if ( $prefdomain && $domain eq $prefdomain ) {
                print "<option selected>$domain\n";
            }
            else {
                print "<option>$domain\n";
            }
        }
        &HTMLEndSelect();
    }
    else {
        print $domains[0];
        &HTMLHidden( "domain", $domains[0] );
    }

}

# Begin-Doc
# Name: SimpleDHCPOptionMenu
# Description: print out a simplified (though hardcoded) dhcp option menu
# End-Doc
sub SimpleDHCPOptionMenu {
    if ( $type ne "cname" && $type ne "server" ) {
        print "  Optional Desktop DHCP Host Options: ";
        &HTMLRadioButton( "dhcpoptions", "",                0, "None" );
        &HTMLRadioButton( "dhcpoptions", "PXE-CMDESK-PROD", 1, "Windows Desktop PXE" );
        &HTMLRadioButton( "dhcpoptions", "PXE-RST",         0, "Linux Desktop PXE" );
        print "<p/>\n";
    }
}

# Begin-Doc
# Name: SimpleHostIndexMenu
# Description: print out a available host index menu
# End-Doc
sub SimpleHostIndexMenu {
        my @tmp = $hosts->GetFreeIndexes( owner => $owner, nametype => $nametype );
        if ( scalar(@tmp) > 1 ) {
            &HTMLStartSelect( "index", 1 );
            print "<option value=\"##\">auto\n";
            foreach my $i ( $hosts->GetFreeIndexes( owner => $owner, nametype => $nametype ) ) {
                print "<option>$i\n";
            }
            &HTMLEndSelect();
        }
        else {
            print $tmp[0];
            &HTMLHidden( "index", $tmp[0] );
        }
}
