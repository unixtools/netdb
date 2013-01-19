
=begin

Begin-Doc
Name: RPC::NetDBAdmin
Type: module
Description: NetDB system admin update methods
End-Doc

=cut

package RPC::NetDBAdmin;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::PrivSys;
use NetMaint::Register;
use NetMaint::Hosts;
use NetMaint::DNS;
use NetMaint::DHCP;
use NetMaint::DB;
use NetMaint::Access;

@ISA    = qw(Exporter);
@EXPORT = qw(
);

#
# Global DB Connection Handles
#
my $db;
my $db_last_ping;

sub _init_db {
    my $self = shift;

    if ( $db && $db->dbhandle ) {
        if ( time - $db_last_ping > 60 ) {
            if ( !$db->dbhandle->ping() ) {
                undef $db;
            }
            else {
                $db_last_ping = time;
            }
        }
    }

    # If no db handle open, or we had an error above, connect to database
    if ( !$db || !$db->dbhandle ) {
        &NetMaint::DB::CloseDB();
        $db = new NetMaint::DB;

        $db_last_ping = time;
    }

    return $db;
}

=begin
Begin-Doc
Name: new
Type: method
Description: creates new NetDBAdmin object
Syntax: $obj = new RPC::NetDBAdmin;
Comments: internal use only
End-Doc
=cut

sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};


    bless $tmp, $class;

    return $tmp;
}

# Begin-Doc
# Name: GetHostInfo
# Type: method
# Description: Returns informtation for a particular hostname in a hash
# Syntax: $hostinfo = $obj->GetHostInfo($host);
# End-Doc
sub GetHostInfo {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $access = new NetMaint::Access;
    my $hosts  = new NetMaint::Hosts;

    my $view_ok = $access->CheckHostViewAccess( host => $host );

    if ( !$view_ok ) {
        die "User doesn't have permission to view this host.";
    }

    my $info = $hosts->GetHostInfo($host);
    return $info;
}

# Begin-Doc
# Name: GetHostDescription
# Type: method
# Description: Returns description for a particular hostname in a hash
# Syntax: $info = $obj->GetHostDescription($host);
# End-Doc
sub GetHostDescription {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $view_ok = $access->CheckHostViewAccess( host => $host, action => "update" );

    if ( !$view_ok ) {
        die "User doesn't have permission to view this host.";
    }

    $qry = "select description from hosts where host=?";
    $cid = $db->SQL_OpenQuery( $qry, $host ) || $db->SQL_Error($qry) && die;

    my ($description) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return { $host => { description => $description } };
}

# Begin-Doc
# Name: SetHostDescription
# Type: method
# Description: Sets description for a particular hostname in a hash
# Syntax: $info = $obj->SetHostDescription($host, $desc);
# End-Doc
sub SetHostDescription {
    my $self = shift;
    my $host = lc shift;
    my $desc = shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    $qry = "update hosts set description=? where host=?";
    $db->SQL_ExecQuery( $qry, $desc, $host ) || $db->SQL_Error($qry) && die;

    return { $host => { description => $desc } };
}

# Begin-Doc
# Name: GetHostLocation
# Type: method
# Description: Returns location for a particular hostname in a hash
# Syntax: $info = $obj->GetHostLocation($host);
# End-Doc
sub GetHostLocation {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $view_ok = $access->CheckHostViewAccess( host => $host, action => "update" );

    if ( !$view_ok ) {
        die "User doesn't have permission to view this host.";
    }

    $qry = "select location from hosts where host=?";
    $cid = $db->SQL_OpenQuery( $qry, $host ) || $db->SQL_Error($qry) && die;

    my ($loc) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return { $host => { location => $loc } };
}

# Begin-Doc
# Name: SetHostLocation
# Type: method
# Description: Sets location for a particular hostname in a hash
# Syntax: $info = $obj->SetHostLocation($host, $loc);
# End-Doc
sub SetHostLocation {
    my $self = shift;
    my $host = lc shift;
    my $loc  = shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    $qry = "update hosts set location=? where host=?";
    $db->SQL_ExecQuery( $qry, $loc, $host ) || $db->SQL_Error($qry) && die;

    return { $host => { location => $loc } };
}

# Begin-Doc
# Name: AutoAllocateVMWareAddr
# Type: method
# Description: Adds vmware auto-allocated mac address to a host
# Syntax: $info = $obj->AutoAllocateVMWareAddr($host);
# End-Doc
sub AutoAllocateVMWareAddr {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    my $dhcp  = new NetMaint::DHCP;
    my $ether = $dhcp->AutoAllocateVMWareEther($host);

    return { $host => { ether => $ether } };
}

# Begin-Doc
# Name: AddEther
# Type: method
# Description: Adds ethernet address to host
# Syntax: $info = $obj->AddEther($host, $ether);
# End-Doc
sub AddEther {
    my $self  = shift;
    my $host  = lc shift;
    my $ether = shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;
    my $util   = new NetMaint::Util;

    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );
    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    my $ether = $util->CondenseEther($ether);
    if ( !$ether ) {
        die "Invalid Ether ($ether)";
    }

    my $eth_check_msg = $util->CheckValidEther($ether);
    if ( $ether && $eth_check_msg ) {
        die "$eth_check_msg";
    }

    my $newhost = $dhcp->SearchByEtherExact($ether);
    if ($newhost) {
        die "Ethernet Address (" . $util->FormatEther($ether) . ") already registered to '" . $newhost . "'.";
    }

    my $nametype = $access->GetHostNameType($host);
    if ( $nametype eq "ownername" || $nametype eq "travelname" ) {
        my $hinfo = $hosts->GetHostInfo($host);
        my $owner = $hinfo->{owner};
        my $cnt   = $access->GetUsedQuota($owner);
        my $quota = $access->GetRegistrationQuota($owner);

        if ( $cnt >= $quota ) {
            die "Owner '$owner' is at or has exceeded registration quota. ($quota)";
        }
    }

    $dhcp->AddHostEther( $host, $ether );
    $hosts->MarkUpdated($host);

    return { $host => { ether => $ether } };
}

# Begin-Doc
# Name: RemoveEther
# Type: method
# Description: Removes ethernet address from host
# Syntax: $info = $obj->RemoveEther($host, $ether);
# End-Doc
sub RemoveEther {
    my $self  = shift;
    my $host  = lc shift;
    my $ether = shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;
    my $util   = new NetMaint::Util;

    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );
    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    my $ether = $util->CondenseEther($ether);
    if ( !$ether ) {
        die "Invalid Ether ($ether)";
    }

    $dhcp->DeleteHostEther( $host, $ether );
    $hosts->MarkUpdated($host);

    return { $host => { ether => $ether } };
}

# Begin-Doc
# Name: GetHostOptions
# Type: method
# Description: Returns host options for a particular hostname in a hash
# Syntax: $info = $obj->GetHostOptions($host);
# End-Doc
sub GetHostOptions {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;

    my $view_ok = $access->CheckHostViewAccess( host => $host, action => "update" );

    if ( !$view_ok ) {
        die "User doesn't have permission to view this host.";
    }

    my %has_option = ();
    my @options    = $dhcp->GetHostOptions($host);

    foreach my $opt (@options) {
        my $opttext = $opt->{option};

        if ( $opttext =~ /^#\s*([A-Z0-9a-z\-\_]+)\s*$/ ) {
            $has_option{$1} = 1;
        }
    }

    return [ keys %has_option ];
}

# Begin-Doc
# Name: GetAdminOptions
# Type: method
# Description: Returns admin host options for a particular hostname in a hash
# Syntax: $info = $obj->GetAdminOptions($host);
# End-Doc
sub GetAdminOptions {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $db = $self->_init_db();

    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;

    my $view_ok = $access->CheckHostViewAccess( host => $host, action => "update" );

    if ( !$view_ok ) {
        die "User doesn't have permission to view this host.";
    }

    my %has_option = ();
    my @options    = $dhcp->GetAdminOptions($host);

    foreach my $opt (@options) {
        my $opttext = $opt->{option};

        if ( $opttext =~ /^#\s*([A-Z0-9a-z\-\_]+)\s*$/ ) {
            $has_option{$1} = 1;
        }
    }

    return [ keys %has_option ];
}

# Begin-Doc
# Name: AddHostOption
# Type: method
# Description: Adds a host option to a host
# Syntax: $info = $obj->AddHostOption($host, $option);
# End-Doc
sub AddHostOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;
    my ( $qry, $cid );


    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;

    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    if ( $dhcp->IsValidOption($option) ) {
        $dhcp->AddHostOption( $host, $option );
    }
    else {
        die "Invalid option '$option' for host '$host'";
    }

    $hosts->MarkUpdated($host);

    return {};
}

# Begin-Doc
# Name: RemoveHostOption
# Type: method
# Description: Removes a host option from a host
# Syntax: $info = $obj->RemoveHostOption($host, $option);
# End-Doc
sub RemoveHostOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;
    my ( $qry, $cid );


    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;

    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    $dhcp->DeleteHostOption( $host, $option );
    $hosts->MarkUpdated($host);

    return {};
}

# Begin-Doc
# Name: AddAdminOption
# Type: method
# Description: Adds a admin option to a host
# Syntax: $info = $obj->AddAdminOption($host, $option);
# End-Doc
sub AddAdminOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;
    my ( $qry, $cid );


    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;

    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    if ( !$access->Check( flag => "adminoption", action => "update" ) ) {
        die "Permission Denied to add/remove admin options.";
    }

    if ( $dhcp->IsValidAdminOption($option) ) {
        $dhcp->AddAdminOption( $host, $option );
    }
    else {
        die "Invalid option '$option' for host '$host'";
    }

    $hosts->MarkUpdated($host);

    return {};
}

# Begin-Doc
# Name: RemoveAdminOption
# Type: method
# Description: Removes a admin option from a host
# Syntax: $info = $obj->RemoveAdminOption($host, $option);
# End-Doc
sub RemoveAdminOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;
    my ( $qry, $cid );


    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;

    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

    if ( !$edit_ok ) {
        die "User doesn't have permission to edit this host.";
    }

    if ( !$access->Check( flag => "adminoption", action => "update" ) ) {
        die "Permission Denied to add/remove admin options.";
    }

    $dhcp->DeleteAdminOption( $host, $option );
    $hosts->MarkUpdated($host);

    return {};
}

# Begin-Doc
# Name: DeleteHost
# Type: method
# Description: Deletes a host
# Syntax: $info = $obj->DeleteHost($host)
# End-Doc
sub DeleteHost {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );


    my $access   = new NetMaint::Access;
    my $hosts    = new NetMaint::Hosts;
    my $register = new NetMaint::Register;

    my $delete_ok = $access->CheckHostDeleteAccess( host => $host, action => "delete" );

    if ( !$delete_ok ) {
        die "User doesn't have permission to delete this host.";
    }

    $register->DeleteHost($host);

    return {};
}

# Begin-Doc
# Name: CreateHost
# Type: method
# Description: Creates a host
# Syntax: $info = $obj->CreateHost(%opts);
# Comments: %opts has keys: owner, index, nametype, domain, type, hostname, image
# End-Doc
sub CreateHost {
    my $self = shift;
    my %opts = @_;
    my ( $qry, $cid );


    my $access = new NetMaint::Access;
    my $dhcp   = new NetMaint::DHCP;
    my $hosts  = new NetMaint::Hosts;
    my $util   = new NetMaint::Util;

    my $owner    = $opts{owner};
    my $index    = $opts{index};
    my $nametype = $opts{nametype};
    my $hostname = $opts{hostname};
    my $domain   = $opts{domain};
    my $type     = $opts{type};
    my $image    = $opts{image};

    my %privs = &PrivSys_FetchPrivs( $ENV{REMOTE_USER} );

    if ( $owner && !$util->UserInfo($owner) ) {
        die "Invalid owner, userid does not exist.";
    }

    if ( $index eq "##" ) {
        my @free = $hosts->GetFreeIndexes( owner => $owner, nametype => $nametype );
        my $picked = shift @free;

        if ( !$picked ) {
            die "Unable to determine next available index.";
        }
        $index = $picked;
    }
    $index = int($index);

    if ( $type eq "guest" ) {
        if ( $nametype ne "ownername" ) {
            die "Guest machines must be named for the sponsor/owner.";
        }

        if ( $domain !~ /guest/ ) {
            die "Guest machines must be in the guest subdomain.";
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
        die "Unable to generate hostname from parameters.";
    }

    my $foundtype = $access->GetHostNameType($host);
    if ( $foundtype ne $nametype ) {
        die "Hostname ($host) Invalid - request type ($nametype), determined type ($foundtype)";
    }

    if ( $nametype eq "ownername" ) {
        if ( !$privs{"sysprog:netdb:user-on-behalf"} ) {
            if ( $owner ne $ENV{REMOTE_USER} ) {
                die "Permission Denied (Owner mismatch).";
            }
        }

        if ( $access->GetHostNameType($host) ne "ownername" ) {
            die "Hostname ($host) Invalid";
        }

        my @existing_hosts = $hosts->SearchByOwnerExact($owner);
        foreach my $existing_host (@existing_hosts) {
            if ( $existing_host =~ /r(\d\d)/o ) {
                if ( $index == $1 ) {
                    die "Host index $index already used by $existing_host.";
                }
            }
        }
    }

    my $err = $hosts->CheckNameLength( host => $host );
    if ($err) {
        die $err;
    }

    if (!$access->Check(
            flag   => $nametype,
            domain => $domain,
            type   => $type,
            action => "insert"
        )
        )
    {
        die "Permission Denied (Insert).";
    }

    my $info = $hosts->GetHostInfo($host);
    if ($info) {
        die "Hostname $host already registered.";
    }

    my $cnt   = $access->GetUsedQuota($owner);
    my $quota = $access->GetRegistrationQuota($owner);

    if ( $cnt >= $quota ) {
        die "Owner '$owner' is at or has exceeded registration quota. ($quota)";
    }

    my $res = $hosts->CreateHost(
        host   => $host,
        domain => $domain,
        owner  => $owner,
        type   => $type
    );
    if ($res) {
        die "Failed to register host: $res";
    }

    return {};
}

# Begin-Doc
# Name: GetUtilityCNames
# Type: method
# Description: Returns hash ref to hashes of utility cnames and their targets
# Syntax: $addrsref = $obj->GetUtilityCNames($group1, [$group2, ... ]);
# Comments: If no group is specified, will not return any entries.
# End-Doc
sub GetUtilityCNames {
    my $self   = shift;
    my @groups = @_;

    foreach my $grp (@groups) {
        &PrivSys_QuietRequirePriv("rpc:netdb:utilitycname:$grp");
    }

    my $db  = $self->_init_db();
    my $res = {};

    my $qry = "select name,address from dns_cname where name like ? and name in (select host from hosts)";
    my $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;
    foreach my $grp (@groups) {
        $db->SQL_ExecQuery( $cid, "%.${grp}.spirenteng.com" );
        while ( my ( $name, $tgt ) = $db->SQL_FetchRow($cid) ) {
            $res->{$grp}->{$name} = $tgt;
        }
    }
    $db->SQL_CloseQuery($cid);

    return $res;
}

# Begin-Doc
# Name: DeleteUtilityCNames
# Type: method
# Description: Deletes a list of utility cnames
# Syntax: $addrsref = $obj->DeleteUtilityCNames($host1, [$host2, ... ]);
# Comments: If no group is specified, will not return any entries.
# End-Doc
sub DeleteUtilityCNames {
    my $self  = shift;
    my @hosts = @_;

    foreach my $host (@hosts) {
        $host = lc $host;

        if ( $host =~ m|^([^.]+)\.([^.]+)\.spirenteng\.com$| ) {
            &PrivSys_QuietRequirePriv("rpc:netdb:utilitycname:$2");
        }
        else {
            die "Invalid host format (must be name.group.spirenteng.com).\n";
        }
    }

    my $register = new NetMaint::Register;
    foreach my $host (@hosts) {
        $register->DeleteHost($host);
    }

    return {};
}

# Begin-Doc
# Name: UpdateUtilityCName
# Type: method
# Description: Creates or updates target for a single utility cname
# Syntax: $res = $obj->UpdateUtilityCName($host1 => $tgt1);
# End-Doc
sub UpdateUtilityCName {
    my $self = shift;
    my $host = lc shift;
    my $tgt  = lc shift;


    if ( $host =~ m|^([^.]+)\.([^.]+)\.spirenteng\.com$| ) {
        &PrivSys_QuietRequirePriv("rpc:netdb:utilitycname:$2");
    }
    else {
        die "Invalid host format ($host) (must be name.group.spirenteng.com).\n";
    }

    if ( !gethostbyname($tgt) ) {
        die "Invalid target host format (must resolve in DNS).\n";
    }

    my $hosts = $self->{hosts};
    if ( !$hosts ) {
        $hosts = new NetMaint::Hosts;
        $self->{hosts} = $hosts;
    }
    my $info = $hosts->GetHostInfo($host);

    if ( !$info ) {
        my $domain = $host;
        $domain =~ s/^[^.]+\.//;

        my $res = $hosts->CreateHost(
            host   => $host,
            domain => $domain,
            owner  => "namesrv",
            type   => "cname",
        );
        if ($res) {
            die "Failed to create host ($host): $res\n";
        }

        $info = $hosts->GetHostInfo($host);
    }

    if ( $info && $info->{type} ne "cname" ) {
        die "Host ($host) already exists and is not a cname!";
    }

    if ( !$info ) {
        die "Unable to create host ($host).\n";
    }

    my $dns = $self->{dns};
    if ( !$dns ) {
        $dns = new NetMaint::DNS;
        $self->{dns} = $dns;
    }
    $dns->Update_CNAME_Record( $host, $tgt );

    return undef;
}

1;
