#!/usr/bin/perl

# Begin-Doc
# Name: rename-host.pl
# Type: script
# Description: Renam Host information by single host, detailed
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
require NetMaint::Access;
require NetMaint::Logging;
require NetMaint::Network;
require NetMaint::Register;
require NetMaint::Rename;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Rename Host" );

$html->PageHeader();

my $hosts  = new NetMaint::Hosts;
my $util   = new NetMaint::Util;
my $dns    = new NetMaint::DNS;
my $log    = new NetMaint::Logging;
my $access = new NetMaint::Access;
my $rename = new NetMaint::Rename;

my $oldhost = lc $rqpairs{oldhost};

my $mode   = lc $rqpairs{mode} || "hosttype";
my $host   = $rqpairs{host};
my $owner  = $rqpairs{owner};
my $type   = $rqpairs{type};
my $ip     = $rqpairs{ip};
my $subnet = $rqpairs{subnet};
my $domain = $rqpairs{domain};
my $index  = $rqpairs{index};
my $image  = $rqpairs{image};

$log->Log();

my $type     = $rqpairs{type};
my $nametype = $rqpairs{nametype};
my $domain   = $rqpairs{domain};
my $owner    = $rqpairs{owner};

print "<h3>Renaming '$oldhost'</h3><p/>\n";

my $info = $hosts->GetHostInfo($oldhost);
if ( !$info->{type} ) {
    $html->ErrorExit("Host does not exist.");
}

if ( $info->{type} eq "cname" && $mode eq "hosttype" ) {
    if ( $access->Check( type => "cname", action => "insert" ) ) {
        $type = "cname";
        $mode = "nametype";
    }
    else {
        $html->ErrorExit("Permission Denied");
    }
}

# attempt to rename new host by parms passed
# need modes for selecting type, domain, and hostname

my %host_types = (
    "device" => "Device Host",
    "server" => "Server",
);

my %name_types = (
    "ownername"  => "Owner Host Names [r##owner]",
    "customname" => "Custom Host Name [*.domain]",
);

if ( $mode eq "hosttype" ) {

    # first thing we need is to determine what type of host to rename
    # print out list
    print "<h3>Type of Host to Rename To:</h3>\n";

    print "<ul>\n";
    my $cnt = 0;
    foreach my $type ( sort( keys(%host_types) ) ) {
        if ( $access->Check( type => $type, action => "insert" ) ) {
            print
                "<li><a href=\"?oldhost=$oldhost&mode=nametype&type=$type\">",
                $host_types{$type}, " [$type]</a>\n";
            $cnt++;
        }
    }
    print "</ul>\n";

    if ( $cnt == 0 ) {
        print "<h3>You are not authorized to register any hosts.</h3>\n";
    }
}
elsif ( $mode eq "nametype" ) {
    print "<h3>Naming style of <tt>$type</tt> host to rename to:</h3>\n";

    my %privs = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );

    print "<ul>\n";
    my $cnt = 0;
    foreach my $ntype ( sort( keys(%name_types) ) ) {
        if ($access->Check(
                type   => $type,
                flag   => $ntype,
                action => "insert"
            )
            )
        {
            if (   $ntype eq "ownername"
                && $privs{"netmgr-user"} )
            {
                print "<li><a href=\"?oldhost=$oldhost&mode=ownername&";
                print "type=$type&nametype=$ntype\">";
                print $name_types{$ntype}, " [$ntype]</a>\n";
                $cnt++;
            }
            else {
                print "<li><a href=\"?oldhost=$oldhost&mode=hostname&";
                print "type=$type&nametype=$ntype\">";
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
elsif ( $mode eq "ownername" ) {
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "oldhost",  $oldhost );
    &HTMLHidden( "mode",     "hostname" );
    &HTMLHidden( "nametype", $nametype );
    &HTMLHidden( "type",     $type );

    my $defowner = $ENV{REMOTE_USER};
    if ( $type eq "server" ) {
        $defowner = "netdb";
    }

    print "Owner: ";
    my %privs = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );
    if ( $privs{"netmgr-user"} ) {
        &HTMLInputText( "owner", 10, $defowner );
    }
    else {
        print $ENV{REMOTE_USER};
        &HTMLHidden( "owner", $ENV{REMOTE_USER} );
    }
    &HTMLEndSelect();
    print "<p/>\n";
    &HTMLCheckbox( "skip_cnames", 0 );
    print "Do not update CName targets.";

    print "<p/>\n";
    &HTMLSubmit("Rename");
    &HTMLEndForm();
    print "<p/>\n";
}
elsif ( $mode eq "hostname" && $nametype eq "ownername" ) {
    my $owner = $rqpairs{owner} || $ENV{REMOTE_USER};
    my @hosts = sort( $hosts->SearchByOwnerExact($owner) );

    # Note which hosts to skip in list
    my %skip_numbers = ();
    foreach my $host (@hosts) {
        if ( $host =~ /r(\d\d)/o ) {
            $skip_numbers{ int($1) } = 1;
        }
    }

    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "oldhost",  $oldhost );
    &HTMLHidden( "mode",     "rename" );
    &HTMLHidden( "nametype", $nametype );
    &HTMLHidden( "type",     $type );
    print "r";
    &HTMLStartSelect( "index", 1 );
    for ( my $i = 1; $i <= 99; $i++ ) {

        if ( !$skip_numbers{$i} ) {

            print "<option>", sprintf( "%.2d", $i ), "\n";
        }
    }
    &HTMLEndSelect();

    my $defowner = $owner;
    print $owner;
    &HTMLHidden( "owner", $owner );

    print ".";
    my %domains = $dns->GetDomains();
    &HTMLStartSelect( "domain", 1 );
    foreach my $domain ( sort( keys(%domains) ) ) {
        if ($access->Check(
                type   => $type,
                flag   => "ownername",
                domain => $domain,
                action => "insert"
            )
            )
        {
            print "<option>$domain\n";
        }
    }
    &HTMLEndSelect();
    print "<p/>\n";

    &HTMLSubmit("Rename");
    &HTMLEndForm();
    print "<p/>\n";
}
elsif ( $mode eq "hostname" && $nametype eq "customname" ) {
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    &HTMLHidden( "oldhost",  $oldhost );
    &HTMLHidden( "mode",     "rename" );
    &HTMLHidden( "nametype", $nametype );
    &HTMLHidden( "type",     $type );

    my $oldhostname = $oldhost;
    $oldhostname =~ s/\..*//g;
    &HTMLInputText( "hostname", 20, $oldhostname );

    print ".";
    my %domains = $dns->GetDomains();
    &HTMLStartSelect( "domain", 1 );

    foreach my $domain ( sort( keys(%domains) ) ) {
        if ($access->Check(
                type   => $type,
                flag   => "customname",
                domain => $domain,
                action => "insert"
            )
            )
        {
            print "<option>$domain\n";
        }
    }
    &HTMLEndSelect();

    my $defowner = $ENV{REMOTE_USER};
    if (   $type eq "server"
        || $type eq "cname" )
    {
        $defowner = "netdb";
    }

    print "  Owner: ";
    &HTMLInputText( "owner", 10, $defowner );
    print "<p/>\n";

    &HTMLSubmit("Rename");
    &HTMLEndForm();
    print "<p/>\n";
}
elsif ( $mode eq "rename" ) {
    my $owner    = lc $rqpairs{owner};
    my $index    = int( $rqpairs{index} );
    my $image    = lc $rqpairs{image};
    my $domain   = lc $rqpairs{domain};
    my $nametype = $rqpairs{nametype};
    my $hostname = lc $rqpairs{hostname};
    my $type     = $rqpairs{type};
    my $target   = $rqpairs{target};
    my $host;

    my %privs = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );

    if ( $owner && !$util->UserInfo($owner) ) {
        $html->ErrorExit("Invalid owner, userid does not exist.");
    }

    my $shorthost = $hostname;
    $shorthost =~ s/\..*//gio;
    my @old_hosts = $hosts->SearchByName($shorthost);
    foreach my $old_host (@old_hosts) {
        my $shost = $old_host;
        $shost =~ s/\..*//gio;
        if ( $shost eq $shorthost && $hostname ne $old_host ) {
            print "<h3>Short hostname might conflict with '<tt>";
            print $html->SearchLink_Host($old_host);
            print "</tt>'.</h3>\n";
        }
    }

    if ( $nametype eq "ownername" ) {
        $host = sprintf( "s%.2d%s.%s", $index, $owner, $domain );

        if ( !$privs{"netmgr-user"} ) {
            if ( $owner ne $ENV{REMOTE_USER} ) {
                $html->ErrorExit("Permission Denied. Owner not authorized.");
            }
        }

        if ( $access->GetHostNameType($host) ne "ownername" ) {
            $html->ErrorExit("Hostname ($host) Invalid");
        }

        my @existing_hosts = $hosts->SearchByOwnerExact($owner);
        foreach my $existing_host (@existing_hosts) {
            if ( $existing_host =~ /^s(\d\d)/o ) {
                if ( $index == $1 ) {
                    $html->ErrorExit("Host index $index already used by $existing_host.");
                }
            }
        }
    }
    elsif ( $nametype eq "customname" ) {
        $host = sprintf( "%s.%s", $hostname, $domain );

        if ( $access->GetHostNameType($host) ne "customname" ) {
            $html->ErrorExit("Hostname ($host) Invalid.");
        }
    }
    else {
        $html->ErrorExit("Permission Denied.");
    }

    my $err = $hosts->CheckNameLength( host => $host );
    if ($err) {
        $html->ErrorExit($err);
    }

    if (!$access->Check(
            flag   => $nametype,
            domain => $domain,
            type   => $type,
            action => "insert"
        )
        )
    {
        $html->ErrorExit("Permission Denied on new host name.");
    }

    if ( !$access->CheckHostEditAccess( host => $oldhost ) ) {
        $html->ErrorExit("Permission Denied editing old host name.");
    }

    if ( $oldhost eq $host ) {
        $html->ErrorExit("Attempting to rename host to same hostname.");
    }

    print "<h3>Attempting to rename host $oldhost to $host.</h3>\n";

    my $res = $rename->RenameHost(
        oldhost  => $oldhost,
        newhost  => $host,
        newowner => $owner,
        newtype  => $type,
    );
    if ($res) {
        $html->ErrorExit("Failed to register host: $res");
    }

    print "<h3>Host renamed successfully!</h3><p/>\n";

    print "<p/>\n";
    print "<a href=\"edit-host.pl?mode=view&host=$host\">Edit Host Details</a><p/>\n";
}

$html->PageFooter();

