# Begin-Doc
# Name: NetMaint::DHCP
# Type: module
# Description: object to manage access to dhcp information
# End-Doc

package NetMaint::DHCP;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Logging;
require NetMaint::Error;
require NetMaint::LastTouch;
require NetMaint::DBCache;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Block any updates
our $block_updates = 0;

# Keep track of whether any updates occurred.
our $blocked_updates = 0;

# Global error object
our $error = new NetMaint::Error();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::DHCP()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}      = new NetMaint::DB;
    $tmp->{util}    = new NetMaint::Util;
    $tmp->{log}     = new NetMaint::Logging;
    $tmp->{touch}   = new NetMaint::LastTouch;
    $tmp->{dbcache} = new NetMaint::DBCache;


    return bless $tmp, $class;
}

# Begin-Doc
# Name: BlockUpdates
# Type: method
# Description: Prevents update trigger from executing
# Syntax: $obj->BlockUpdates();
# End-Doc
sub BlockUpdates {
    $block_updates++;
}

# Begin-Doc
# Name: UnblockUpdates
# Type: method
# Description: Prevents update trigger from executing
# Syntax: $obj->UnblockUpdates();
# End-Doc
sub UnblockUpdates {
    my $self = shift;
    $block_updates--;

    if ( $blocked_updates > 0 ) {
        $self->TriggerUpdate();
    }
    if ( $block_updates < 1 ) {
        $blocked_updates = 0;
        $block_updates   = 0;
    }
}

# Begin-Doc
# Name: TriggerUpdate
# Type: method
# Description: Triggers a server update
# Syntax: $obj->TriggerUpdate();
# End-Doc
sub TriggerUpdate {
    my $self = shift;
    my $log  = $self->{log};

    # If we're blocking updates, make note, and return
    if ($block_updates) {
        $blocked_updates++;
        return;
    }

    $log->Log( action => "triggered dhcp update", );

    foreach my $server ( "dhcpsrv1", "dhcpsrv2" ) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => "${server}:2405",
            Proto    => "tcp"
        );
        if ($sock) {
            $sock->print("");
            undef($sock);
        }
        else {
            print "Unable to update server ($server) $!.\n";
        }
    }
}

# Begin-Doc
# Name: GetEthers
# Type: method
# Description: Returns array of ethernet addrs registered to a host
# Syntax: @ethers = $obj->GetEthers($host);
# End-Doc
sub GetEthers {
    my $self = shift;
    my $host = shift;

    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );
    my @ethers;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select ether from ethers where name=? order by ether ";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $host )
        || $db->SQL_Error( $qry . " ($host)" ) && return undef;

    while ( my ($ether) = $db->SQL_FetchRow($cid) ) {
        push( @ethers, $ether );
    }

    return @ethers;
}

# Begin-Doc
# Name: GetOptionInfo
# Type: method
# Description: Returns hash of dhcp option labels/info
# Syntax: %options = $obj->GetOptionInfo();
# End-Doc
sub GetOptionInfo {
    my $self = shift;

    my %res;
    my $db  = $self->{db};
    my $qry = "select optionname,label from menu_dhcp_options";
    my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && return ();
    while ( my ( $k, $v ) = $db->SQL_FetchRow($cid) ) {
        $res{$k} = $v;
    }
    $db->SQL_CloseQuery($cid);

    return %res;
}

# Begin-Doc
# Name: GetAdminOptionInfo
# Type: method
# Description: Returns hash of dhcp option labels/info
# Syntax: %options = $obj->GetAdminOptionInfo();
# End-Doc
sub GetAdminOptionInfo {
    my $self = shift;

    my %res;
    my $db  = $self->{db};
    my $qry = "select optionname,label from menu_admin_options";
    my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && return ();
    while ( my ( $k, $v ) = $db->SQL_FetchRow($cid) ) {
        $res{$k} = $v;
    }
    $db->SQL_CloseQuery($cid);

    return %res;
}

# Begin-Doc
# Name: IsValidOption
# Type: method
# Description: Returns if an option is a valid option
# Syntax: $res = $obj->IsValidOption();
# End-Doc
sub IsValidOption {
    my $self = shift;
    my $opt  = shift;
    $opt =~ s/^#*\s*//gio;

    my %valid = $self->GetOptionInfo();

    if ( $valid{$opt} ) {
        return 1;
    }
    return 0;
}

# Begin-Doc
# Name: IsValidAdminOption
# Type: method
# Description: Returns if an option is a valid admin option
# Syntax: $res = $obj->IsValidAdminOption();
# End-Doc
sub IsValidAdminOption {
    my $self = shift;
    my $opt  = shift;
    $opt =~ s/^#*\s*//gio;

    my %valid = $self->GetAdminOptionInfo();

    if ( $valid{$opt} ) {
        return 1;
    }
    return 0;
}

# Begin-Doc
# Name: DeleteHostOptionText
# Type: method
# Description: Deletes an exact textual config option for a host
# Syntax: $obj->DeleteHostOption($host, $option);
# End-Doc
sub DeleteHostOptionText {
    my $self       = shift;
    my $host       = lc shift;
    my $optiontext = shift;

    my $db  = $self->{db};
    my $log = $self->{log};

    my ($qry);

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "delete from dhcp_host_options where host=? and config=?";
    $db->SQL_ExecQuery( $qry, $host, $optiontext )
        || $db->SQL_Error($qry) && return undef;

    $log->Log(
        action => "delete host option text",
        host   => $host,
        option => $optiontext
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: DeleteAdminOptionText
# Type: method
# Description: Deletes an exact textual admin config option for a host
# Syntax: $obj->DeleteAdminOption($host, $option);
# End-Doc
sub DeleteAdminOptionText {
    my $self       = shift;
    my $host       = lc shift;
    my $optiontext = shift;

    my $db  = $self->{db};
    my $log = $self->{log};

    my ($qry);

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "delete from admin_host_options where host=? and config=?";
    $db->SQL_ExecQuery( $qry, $host, $optiontext )
        || $db->SQL_Error($qry) && return undef;

    $log->Log(
        action => "delete admin option text",
        host   => $host,
        option => $optiontext
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: DeleteHostOption
# Type: method
# Description: Deletes an option for a host
# Syntax: $obj->DeleteHostOption($host, $option);
# End-Doc
sub DeleteHostOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;

    my $db  = $self->{db};
    my $log = $self->{log};

    my ($qry);

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $self->BlockUpdates();

    $log->Log(
        action => "delete host option",
        host   => $host,
        option => $option
    );

    $self->DeleteHostOptionText( $host, $option );

    if ( !$self->IsValidOption($option) ) {
        return undef;
    }

    my @options = $self->GetHostOptions($host);

    foreach my $opt (@options) {
        my $opttext = $opt->{option};

        if ( $opttext =~ /^#\s*([A-Z0-9a-z-]+)\s*$/ ) {
            if ( $1 eq $option ) {
                $self->DeleteHostOptionText( $host, $opttext );
            }
        }
    }

    $self->TriggerUpdate();
    $self->UnblockUpdates();
}

# Begin-Doc
# Name: DeleteAdminOption
# Type: method
# Description: Deletes an admin option for a host
# Syntax: $obj->DeleteAdminOption($host, $option);
# End-Doc
sub DeleteAdminOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;

    my $db  = $self->{db};
    my $log = $self->{log};

    my ($qry);

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $self->BlockUpdates();

    $log->Log(
        action => "delete admin option",
        host   => $host,
        option => $option
    );

    $self->DeleteAdminOptionText( $host, $option );

    if ( !$self->IsValidAdminOption($option) ) {
        return undef;
    }

    my @options = $self->GetAdminOptions($host);

    foreach my $opt (@options) {
        my $opttext = $opt->{option};

        if ( $opttext =~ /^#\s*([A-Z0-9a-z\-\_]+)\s*$/ ) {
            if ( $1 eq $option ) {
                $self->DeleteAdminOptionText( $host, $opttext );
            }
        }
    }

    $self->TriggerUpdate();
    $self->UnblockUpdates();
}

# Begin-Doc
# Name: AddHostOption
# Type: method
# Description: Deletes an option for a host
# Syntax: $obj->AddHostOption($host, $option);
# End-Doc
sub AddHostOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;

    my $db  = $self->{db};
    my $log = $self->{log};

    my ($qry);

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $option =~ s/^#*\s*//gio;

    if ( !$self->IsValidOption($option) ) {
        print "Invalid option specified.<P>\n";
        return undef;
    }

    $log->Log(
        action => "add host option",
        host   => $host,
        option => $option
    );

    $self->{touch}->UpdateLastTouch( host => $host );

    $qry = "delete from dhcp_host_options where host=? and config like ?";
    $db->SQL_ExecQuery( $qry, $host, "%" . $option . "%" )
        || $db->SQL_Error($qry) && return undef;

    $qry = "insert into dhcp_host_options(host,config,tstamp) values (?,?,now())";
    $db->SQL_ExecQuery( $qry, $host, "# $option" )
        || $db->SQL_Error($qry) && return undef;

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: AddAdminOption
# Type: method
# Description: Adds an admin option for a host
# Syntax: $obj->AddAdminOption($host, $option);
# End-Doc
sub AddAdminOption {
    my $self   = shift;
    my $host   = lc shift;
    my $option = shift;

    my $db  = $self->{db};
    my $log = $self->{log};

    my ($qry);

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $option =~ s/^#*\s*//gio;

    if ( !$self->IsValidAdminOption($option) ) {
        print "Invalid option specified.<P>\n";
        return undef;
    }

    $log->Log(
        action => "add admin option",
        host   => $host,
        option => $option
    );

    $self->{touch}->UpdateLastTouch( host => $host );

    $qry = "delete from admin_host_options where host=? and config like ?";
    $db->SQL_ExecQuery( $qry, $host, "%" . $option . "%" )
        || $db->SQL_Error($qry) && return undef;

    $qry = "insert into admin_host_options(host,config,tstamp) values (?,?,now())";
    $db->SQL_ExecQuery( $qry, $host, "# $option" )
        || $db->SQL_Error($qry) && return undef;

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: GetHostOptions
# Type: method
# Description: Returns array of dhcp host options
# Syntax: @options = $obj->GetHostOptions($host);
# End-Doc
sub GetHostOptions {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @options;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select config,tstamp from dhcp_host_options where host=? order by tstamp";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $option, $tstamp ) = $db->SQL_FetchRow($cid) ) {
        push(
            @options,
            {   option => $option,
                tstamp => $tstamp,
            }
        );
    }

    return @options;
}

# Begin-Doc
# Name: GetAdminOptions
# Type: method
# Description: Returns array of dhcp host options
# Syntax: @options = $obj->GetAdminOptions($host);
# End-Doc
sub GetAdminOptions {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @options;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select config,tstamp from admin_host_options where host=? order by tstamp";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $option, $tstamp ) = $db->SQL_FetchRow($cid) ) {
        push(
            @options,
            {   option => $option,
                tstamp => $tstamp,
            }
        );
    }

    return @options;
}

# Begin-Doc
# Name: GetAllHostOptions
# Type: method
# Description: Returns ref to hash of arrays of all dhcp host options
# Syntax: $options = $obj->GetAllHostOptions();
# End-Doc
sub GetAllHostOptions {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $res = {};

    $qry = "select host,config from dhcp_host_options";
    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        $error->set("failed to open query to get host options");
        die;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $host, $opt ) = @$rref;
        push( @{ $res->{$host} }, $opt );
    }

    return $res;
}

# Begin-Doc
# Name: GetAllAdminOptions
# Type: method
# Description: Returns ref to hash of arrays of all dhcp host options
# Syntax: $options = $obj->GetAllAdminOptions();
# End-Doc
sub GetAllAdminOptions {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $res = {};

    $qry = "select host,config from admin_host_options";
    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        $error->set("failed to open query to get admin host options");
        die;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $host, $opt ) = @$rref;
        push( @{ $res->{$host} }, $opt );
    }

    return $res;
}

# Begin-Doc
# Name: GetAllSubnetOptions
# Type: method
# Description: Returns ref to hash of arrays of all dhcp subnet options
# Syntax: $options = $obj->GetAllSubnetOptions();
# End-Doc
sub GetAllSubnetOptions {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $res = {};

    $qry = "select subnet,config from dhcp_subnet_options";
    $cid = $db->SQL_OpenQuery($qry) || die;
    my $allrows = $db->SQL_FetchAllRows($cid);
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $sn, $opt ) = @$rref;
        push( @{ $res->{$sn} }, $opt );
    }

    return $res;
}

# Begin-Doc
# Name: SearchByEther
# Type: method
# Description: Returns hash of hostnames with ethers matching substring
# Comments: value of hash is array ref of matching ethernet addresses
# Syntax: %hosts = $obj->SearchByEther($substring, [$max]);
# End-Doc
sub SearchByEther {
    my $self = shift;
    my $pat  = uc shift;
    my $max  = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my %hosts;
    my @vals;

    $qry = "select distinct name,ether from ethers where ether like ?";
    push( @vals, "%" . $pat . "%" );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals ) || $db->SQL_Error($qry) && return undef;
    while ( my ( $host, $ether ) = $db->SQL_FetchRow($cid) ) {
        push( @{ $hosts{$host} }, $ether );
    }
    $db->SQL_CloseQuery($cid);

    return %hosts;
}

# Begin-Doc
# Name: SearchByEtherExact
# Type: method
# Description: Returns hostname with ethers matching exactly
# Syntax: $hosts = $obj->SearchByEtherExact($ether);
# End-Doc
sub SearchByEtherExact {
    my $self  = shift;
    my $ether = shift;

    my $util    = $self->{util};
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );

    $ether = $util->CondenseEther($ether);

    $qry = "select name from ethers where ether=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $ether )
        || $db->SQL_Error( $qry . " ($ether)" ) && return undef;

    my ($host) = $db->SQL_FetchRow($cid);

    return $host;
}

# Begin-Doc
# Name: SearchByAdminOption
# Type: method
# Description: Returns hostnames with particular admin option
# Syntax: $hosts = $obj->SearchByAdminOption($option);
# End-Doc
sub SearchByAdminOption {
    my $self   = shift;
    my $option = shift;
    my $hosts  = [];

    my $util    = $self->{util};
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );

    $qry = "select host from admin_host_options where config=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, "# $option" )
        || $db->SQL_Error( $qry . " (# $option)" ) && return undef;

    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @$hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return $hosts;
}

# Begin-Doc
# Name: SearchByDHCPOption
# Type: method
# Description: Returns hostnames with particular dhcp option
# Syntax: $hosts = $obj->SearchByDHCPOption($option);
# End-Doc
sub SearchByDHCPOption {
    my $self   = shift;
    my $option = shift;
    my $hosts  = [];

    my $util    = $self->{util};
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );

    $qry = "select host from dhcp_host_options where config=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, "# $option" )
        || $db->SQL_Error( $qry . " (# $option)" ) && return undef;

    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @$hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return $hosts;
}

# Begin-Doc
# Name: GetDHCPHistory
# Type: method
# Description: Returns array ref of arp history records matching a particular ethernet addr or ip
# Syntax: $recs = $obj->GetDHCPHistory(%filter);
# Comments: %filter has keys "ether" and/or "ip", at least one of 'ether' or 'ip' must be specified
# Comments: returns undef if not found
# End-Doc
sub GetDHCPHistory {
    my $self   = shift;
    my %filter = @_;
    my $ether  = $filter{ether};
    my $ip     = $filter{ip};

    my $util = $self->{util};
    my $db   = $self->{db};

    my ( $qry, $cid );
    my $info = [];

    if ( !$ether && !$ip ) {
        return undef;
    }

    my @where = ();
    my @vals  = ();
    if ($ether) {
        push( @where, "ether=?" );
        push( @vals,  $util->CondenseEther($ether) );
    }
    if ($ip) {
        push( @where, "ip=?" );
        push( @vals,  $util->CondenseIP($ip) );
    }

    $qry
        = "select type, ether, ip, tstamp, server, gateway from dhcp_acklog where "
        . join( " and ", @where )
        . " order by tstamp";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $qtype, $qeth, $qip, $qtstamp, $qserver, $qgw ) = $db->SQL_FetchRow($cid) ) {
        push(
            @$info,
            {   type    => $qtype,
                ether   => $qeth,
                ip      => $qip,
                tstamp  => $qtstamp,
                server  => $qserver,
                gateway => $qgw
            }
        );
    }

    return $info;
}

# Begin-Doc
# Name: DeleteHost
# Type: method
# Description: Deletes all ethernet and dhcp data associated with a host
# Syntax: $obj->DeleteHost($host);
# End-Doc
sub DeleteHost {
    my $self = shift;
    my $host = lc shift;
    my $log  = $self->{log};

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "delete from dhcp_host_options where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $qry = "delete from admin_host_options where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $qry = "delete from ethers where name=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $log->Log(
        action => "delete dhcp host",
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: DeleteHostEther
# Type: method
# Description: Deletes single ethernet address associated with a host
# Syntax: $obj->DeleteHostEther($host, $ether);
# End-Doc
sub DeleteHostEther {
    my $self  = shift;
    my $host  = lc shift;
    my $ether = shift;
    my $log   = $self->{log};

    my $db   = $self->{db};
    my $util = $self->{util};

    $ether = $util->CondenseEther($ether);

    my ( $qry, $cid );

    $qry = "delete from ethers where name=? and ether=?";
    $db->SQL_ExecQuery( $qry, $host, $ether ) || $db->SQL_Error($qry);

    $log->Log(
        action => "delete dhcp host ether",
        host   => $host,
        ether  => $ether,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: AddHostEther
# Type: method
# Description: Adds an ethernet address to a host
# Syntax: $obj->AddHostEther($host, $ether);
# End-Doc
sub AddHostEther {
    my $self  = shift;
    my $host  = lc shift;
    my $ether = shift;
    my $log   = $self->{log};

    my $db   = $self->{db};
    my $util = $self->{util};

    if ( !$ether ) {
        $error->set("unable to insert null ethernet address");
        print "unable to insert null ethernet addr!<P>\n";
        return undef;
    }

    $ether = $util->CondenseEther($ether);

    if ( !$host ) {
        $error->set("unable to insert null hostname");
        print "unable to insert for null host!<P>\n";
        return undef;
    }

    if ( length($ether) != 12 ) {
        $error->set("unable to insert invalid ethernet address");
        print "unable to insert invalid ethernet addr!<P>\n";
        return undef;
    }

    $self->{touch}->UpdateLastTouch( host => $host, ether => $ether );

    my ( $qry, $cid );

    $qry = "insert into ethers (name,ether) values (?,?)";
    $db->SQL_ExecQuery( $qry, $host, $ether )
        || $db->SQL_Error($qry) && $error->set("error inserting ether");

    if ( !$error->check() ) {
        $log->Log(
            action => "added dhcp host ether",
            host   => $host,
            ether  => $ether,
        );

        $self->TriggerUpdate();
    }
    else {
        $log->Log(
            action => "failed to add dhcp host ether",
            host   => $host,
            ether  => $ether,
        );
    }
}

# Begin-Doc
# Name: AutoAllocateVMWareEther
# Type: method
# Description: Allocates next available VMWare ethernet address
# Syntax: $ether = $obj->AutoAllocateVMWareEther($host)
# End-Doc
sub AutoAllocateVMWareEther {
    my $self = shift;
    my $host = shift;

    return $self->AutoAllocateEther( $host, "0050563f" );
}

# Begin-Doc
# Name: AutoAllocateEther
# Type: method
# Description: Allocates next available ethernet address matching a prefix
# Syntax: $ether = $obj->AutoAllocateEther($host, $prefix)
# End-Doc
sub AutoAllocateEther {
    my $self   = shift;
    my $host   = shift;
    my $prefix = uc shift;
    my $log    = $self->{log};
    my $db     = $self->{db};

    $log->Log(
        action => "attempting to auto-allocate ethernet address with prefix $prefix",
        host   => $host,
    );

    my %in_use = ();

    my $qry = "select distinct lower(ether) from ethers where ether like ?";
    my $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $prefix . "%" )
        || $db->SQL_Error($qry) && return undef;

    while ( my ($eth) = $db->SQL_FetchRow($cid) ) {
        $in_use{ uc $eth } = 1;
    }

    # determine length of prefix
    my $nibbles = 12 - length($prefix);
    my $high    = hex( "F" x $nibbles );
    if ( $high > 1000 ) {
        $high = 1000;
    }

    # Now loop through a thousand or so addresses, and make note of first available
    for ( my $offset = 1; $offset <= $high; $offset++ ) {
        my $tryeth = sprintf( "%s%.${nibbles}X", uc $prefix, $offset );
        if ( !$in_use{$tryeth} ) {
            $self->AddHostEther( $host, $tryeth );
            if ( !$error->check() ) {
                return $tryeth;
            }
            else {
                print "<BR>failed on $tryeth\n";
                print $error->as_html();
            }
        }
    }

    return undef;
}

1;
