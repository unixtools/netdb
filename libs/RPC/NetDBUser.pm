
=begin

Begin-Doc
Name: RPC::NetDBUser
Type: module
Description: Privilege system admin update methods
End-Doc

=cut

package RPC::NetDBUser;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use UMR::UsageLogger;
use NetMaint::DB;

@ISA    = qw(Exporter);
@EXPORT = qw(
);

#
# Global subnets
#
my $subnets;
my $subnets_last_fetch;
my $vlans;
my $vlans_last_fetch;

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
Description: creates new NetDBUser object
Syntax: $obj = new RPC::NetDBUser;
Comments: internal use only
End-Doc
=cut

sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    &LogAPIUsage();

    bless $tmp, $class;

    return $tmp;
}

# Begin-Doc
# Name: GetSubnets
# Type: method
# Description: Returns data for all subnets
# Syntax: $subnetinfo = $obj->GetSubnets();
# Comments: caches subnet info details for fast repeated lookup
# End-Doc
sub GetSubnets {
    my $self = shift;
    my ( $qry, $cid );

    &LogAPIUsage();

    if ( $subnets && ( time - $subnets_last_fetch ) < 15 * 60 ) {
        return $subnets;
    }

    if ( !$subnets ) {
        $subnets = {};
    }

    my $db = $self->_init_db();

    $qry = "select subnet,description,mask,vlan,gateway,template from subnets";
    $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

    while ( my ( $subnet, $desc, $mask, $vlan, $gw, $tmpl ) = $db->SQL_FetchRow($cid) ) {
        my $tmp = {};
        $subnets->{$subnet} = $tmp;

        $tmp->{description} = $desc;
        $tmp->{mask}        = $mask;
        $tmp->{vlan}        = $vlan;
        $tmp->{gateway}     = $gw;
        $tmp->{template}    = $tmpl;
    }
    $db->SQL_CloseQuery($cid);

    return $subnets;
}

# Begin-Doc
# Name: GetVLANs
# Type: method
# Description: Returns data for all vlans
# Syntax: $vlaninfo = $obj->GetVLANs()
# Comments: caches vlan info details for fast repeated lookup
# End-Doc
sub GetVLANs {
    my $self = shift;
    my ( $qry, $cid );

    &LogAPIUsage();

    if ( $vlans && ( time - $vlans_last_fetch ) < 15 * 60 ) {
        return $vlans;
    }

    if ( !$vlans ) {
        $vlans = {};
    }

    my $db = $self->_init_db();

    $qry = "select vlan,name from vlans";
    $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

    while ( my ( $vlan, $name ) = $db->SQL_FetchRow($cid) ) {
        my $tmp = {};
        $vlans->{$vlan} = $tmp;

        $tmp->{name} = $name;
    }
    $db->SQL_CloseQuery($cid);

    return $vlans;
}

# Begin-Doc
# Name: HostToOwner
# Type: method
# Description: Returns owner userid for a host
# Syntax: $owner = $obj->HostToOwner($hostname);
# End-Doc
sub HostToOwner {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );
    my ($owner);

    &LogAPIUsage();

    my $db = $self->_init_db();

    $qry = "select owner from hosts where host=?";
    $cid = $db->SQL_OpenQuery( $qry, $host ) || $db->SQL_Error($qry) && die;
    ($owner) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return $owner;
}

# Begin-Doc
# Name: OwnerToHosts
# Type: method
# Description: Returns ref to array of hosts owned by a userid
# Syntax: $hosts = $obj->OwnerToHosts($userid);
# End-Doc
sub OwnerToHosts {
    my $self   = shift;
    my $userid = lc shift;
    my ( $qry, $cid );
    my @hosts;

    &LogAPIUsage();

    my $db = $self->_init_db();

    $qry = "select host from hosts where owner=?";
    $cid = $db->SQL_OpenQuery( $qry, $userid ) || $db->SQL_Error($qry) && die;
    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return \@hosts;
}

# Begin-Doc
# Name: HostToEther
# Type: method
# Description: Returns ref to array of ethernet addresses for a host
# Syntax: $ethers = $obj->HostToEther($hostname);
# End-Doc
sub HostToEther {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );
    my ($ether);
    my @ethers;

    &LogAPIUsage();

    my $db = $self->_init_db();

    $qry = "select ether from ethers where name=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;

    while ( ($ether) = $db->SQL_FetchRow($cid) ) {
        push( @ethers, $ether );
    }
    $db->SQL_CloseQuery($cid);

    return \@ethers;
}

# Begin-Doc
# Name: EtherToHost
# Type: method
# Description: Returns hostname with a particular ethernet addr
# Syntax: $host = $obj->EtherToHost($ether);
# End-Doc
sub EtherToHost {
    my $self  = shift;
    my $ether = shift;
    my ( $qry, $cid );

    &LogAPIUsage();

    $ether = uc $ether;
    $ether =~ tr/0-9A-F//cd;
    if ( length($ether) != 12 ) {
        return undef;
    }

    my $db = $self->_init_db();

    # Should add caching
    $qry = "select name from ethers where ether=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;
    $db->SQL_ExecQuery( $cid, $ether ) || $db->SQL_Error($qry) && die;

    my ($host) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return $host;
}

# Begin-Doc
# Name: LastLeaseToEther
# Type: method
# Description: Returns last ether to lease a particular IP addr
# Syntax: $ether = $obj->LastLeaseToEther($ip);
# End-Doc
sub LastLeaseToEther {
    my $self = shift;
    my $ip   = shift;
    my $ether;
    my ( $qry, $cid );

    &LogAPIUsage();

    my $db = $self->_init_db();

    $qry = "select ether from dhcp_curleases where ip=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;
    $db->SQL_ExecQuery( $cid, $ip ) || $db->SQL_Error($qry) && die;

    my ($ether) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return $ether;
}

# Begin-Doc
# Name: LastLeaseToHost
# Type: method
# Description: Returns last host to lease a particular IP addr
# Syntax: $ether = $obj->LastLeaseToHost($ip);
# End-Doc
sub LastLeaseToHost {
    my $self = shift;
    my $ip   = shift;
    my $ether;
    my ( $qry, $cid );

    &LogAPIUsage();

    my $db = $self->_init_db();

    $qry = "select ether from dhcp_curleases where ip=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;
    $db->SQL_ExecQuery( $cid, $ip ) || $db->SQL_Error($qry) && die;

    my ($ether) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return $self->EtherToHost($ether);
}

# Begin-Doc
# Name: MatchPartialHost
# Type: method
# Description: Returns hostnames containing a substring
# Syntax: @hosts = $obj->MatchPartialHost($pattern);
# End-Doc
sub MatchPartialHost {
    my $self = shift;
    my $pat  = lc shift;
    my ( $qry,  $cid );
    my ( $host, @hosts );

    &LogAPIUsage();

    my $db = $self->_init_db();

    if ( $pat eq "" || $pat !~ /^[\.a-z0-9-_]+$/o ) {
        return ();
    }

    $qry = "select host from hosts where host like ?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;
    $db->SQL_ExecQuery( $cid, "%" . $pat . "%" ) || $db->SQL_Error($qry) && die;

    while ( ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return \@hosts;
}

# Begin-Doc
# Name: ValidFQDN
# Type: method
# Description: Returns true/nonzero if a host exists
# Syntax: $res = $obj->ValidFQDN($host);
# End-Doc
sub ValidFQDN {
    my $self = shift;
    my $host = lc shift;
    my ( $qry, $cid );

    &LogAPIUsage();

    my $db = $self->_init_db();

    $qry = "select count(*) from hosts where host=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && die;
    my ($cnt) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    return $cnt;
}

1;
