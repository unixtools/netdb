# Begin-Doc
# Name: NetMaint::Network
# Type: module
# Description: object to manage access to all network config info
# Comments: This has access to subnet configs, ip allocations, ethernet address lookup, etc.
# End-Doc

package NetMaint::Network;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require NetMaint::DB;
require NetMaint::Util;
require NetMaint::DBCache;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Network()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}      = new NetMaint::DB;
    $tmp->{subnets} = undef;
    $tmp->{util}    = new NetMaint::Util;
    $tmp->{dbcache} = new NetMaint::DBCache;

    return bless $tmp, $class;
}

# Begin-Doc
# Name: GetAddresses
# Type: method
# Description: Returns full list of addresses for a given subnet
# Syntax: %res = $obj->GetAddresses($subnet);
# End-Doc
sub GetAddresses {
    my $self   = shift;
    my $subnet = shift;
    my $type   = shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my %res;

    my $cache = $self->{dbcache};
    $qry = "select ip,type from ip_alloc where subnet=?";
    $cid = $cache->open($qry);
    $db->SQL_ExecQuery( $cid, $subnet )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $ip, $type ) = $db->SQL_FetchRow($cid) ) {
        $res{$ip} = $type;
    }

    return %res;
}

# Begin-Doc
# Name: ClearSubnetCache
# Type: method
# Description: Clears cache of subnet details
# Syntax: $obj->ClearSubnetCache();
# End-Doc
sub ClearSubnetCache {
    my $self = shift;
    $self->{subnets} = undef;
}

# Begin-Doc
# Name: SetIPAllocation
# Type: method
# Description: Updates allocation for an IP
# Syntax: $obj->SetIPAllocation($ip, $type);
# End-Doc
sub SetIPAllocation {
    my $self = shift;
    my $ip   = shift;
    my $type = lc shift;
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "update ip_alloc set type=? where ip=?";
    $cid = $db->SQL_ExecQuery( $qry, $type, $ip )
        || $db->SQL_Error($qry) && return undef;
}

# Begin-Doc
# Name: DeleteSubnet
# Type: method
# Description: Deletes all allocations and information for a subnet
# Syntax: $obj->DeleteSubnet($subnet);
# End-Doc
sub DeleteSubnet {
    my $self   = shift;
    my $subnet = shift;
    my $db     = $self->{db};

    my ( $qry, $cid );

    $qry = "delete from ip_alloc where subnet=?";
    $cid = $db->SQL_ExecQuery( $qry, $subnet )
        || $db->SQL_Error($qry) && return undef;

    $qry = "delete from subnets where subnet=?";
    $cid = $db->SQL_ExecQuery( $qry, $subnet )
        || $db->SQL_Error($qry) && return undef;

    $self->ClearSubnetCache();
}

# Begin-Doc
# Name: DeallocateAddress
# Type: method
# Description: Attempts to allocate an address to a host
# Syntax: $obj->DeallocateAddress($ip, $host);
# End-Doc
sub DeallocateAddress {
    my $self = shift;
    my $ip   = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "update ip_alloc set host='' where ip=? and type != 'dynamic' and host=?";
    $cid = $db->SQL_ExecQuery( $qry, $ip, $host )
        || $db->SQL_Error($qry) && return undef;
    my $rows = $db->SQL_RowCount($cid);

    return $rows == 1;
}

# Begin-Doc
# Name: AllocateAddress
# Type: method
# Description: Attempts to allocate an address to a host
# Syntax: $obj->AllocateAddress($ip, $host);
# End-Doc
sub AllocateAddress {
    my $self = shift;
    my $ip   = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "update ip_alloc set host=? where ip=? and type != 'dynamic' and (host='' or host is null)";
    $cid = $db->SQL_ExecQuery( $qry, $host, $ip )
        || $db->SQL_Error($qry) && return undef;
    my $rows = $db->SQL_RowCount($cid);

    return $rows == 1;
}

# Begin-Doc
# Name: GetAddressDetail
# Type: method
# Description: Returns details for a single address
# Syntax: %info = $obj->GetAddressDetail($ip);
# Returns: hash keyed on ip, type, host
# End-Doc
sub GetAddressDetail {
    my $self = shift;
    my $ip   = shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my %res;

    my $cache = $self->{dbcache};
    $qry = "select ip,subnet,type,host from ip_alloc where ip=?";
    $cid = $cache->open($qry);
    $db->SQL_ExecQuery( $cid, $ip )
        || $db->SQL_Error($qry) && return undef;

    my ( $ip, $subnet, $type, $host ) = $db->SQL_FetchRow($cid);
    $res{ip}     = $ip;
    $res{subnet} = $subnet;
    $res{type}   = $type;
    $res{host}   = $host;

    $db->SQL_CloseQuery($cid);

    return %res;
}

# Begin-Doc
# Name: GetAddressesDetail
# Type: method
# Description: Returns full list of addresses for a given subnet with full details
# Syntax: $info = $obj->GetAddressesDetail($subnet);
# Returns: hash keyed on ip, values is hash keyed on ip, type, host
# End-Doc
sub GetAddressesDetail {
    my $self   = shift;
    my $subnet = shift;
    my $type   = shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my $res = {};

    $qry = "select ip,type,host from ip_alloc where subnet=?";
    $cid = $db->SQL_OpenQuery( $qry, $subnet )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $ip, $type, $host ) = $db->SQL_FetchRow($cid) ) {
        $res->{$ip}->{ip}   = $ip;
        $res->{$ip}->{type} = $type;
        $res->{$ip}->{host} = $host;
    }
    $db->SQL_CloseQuery($cid);

    return $res;
}

# Begin-Doc
# Name: GetHostAddresses
# Type: method
# Description: Returns list of allocated addresses for a given host
# Syntax: @addresses = $obj->GetHostAddresses($host)
# End-Doc
sub GetHostAddresses {
    my $self = shift;
    my $host = lc shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @res;

    my $cache = $self->{dbcache};
    $qry = "select ip,type from ip_alloc where host=?";
    $cid = $cache->open($qry);
    $db->SQL_ExecQuery( $cid, $host )
        || $db->SQL_Error($qry) && return undef;

    while ( my ($ip) = $db->SQL_FetchRow($cid) ) {
        push( @res, $ip );
    }
    $db->SQL_CloseQuery($cid);

    return @res;
}

# Begin-Doc
# Name: GetAllocatedAddresses
# Type: method
# Description: Returns list of allocated addresses for a given subnet of a particular type
# Syntax: @addresses = $obj->GetAllocatedAddresses($subnet, $type);
# End-Doc
sub GetAllocatedAddresses {
    my $self   = shift;
    my $subnet = shift;
    my $type   = shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @res;

    $qry = "select ip from ip_alloc where subnet=? and type=?";
    $cid = $db->SQL_OpenQuery( $qry, $subnet, $type )
        || $db->SQL_Error($qry) && return undef;

    while ( my ($ip) = $db->SQL_FetchRow($cid) ) {
        push( @res, $ip );
    }
    $db->SQL_CloseQuery($cid);

    return @res;
}

# Begin-Doc
# Name: GetAllocationTypeCounts
# Type: method
# Description: Returns hash of allocated addresses for a given subnet of a particular type
# Syntax: %counts = $obj->GetAllocationTypeCounts($subnet);
# End-Doc
sub GetAllocationTypeCounts {
    my $self   = shift;
    my $subnet = shift;
    my %counts = ();

    my $db = $self->{db};
    my ( $qry, $cid );
    my @res;

    $qry = "select type,count(*) from ip_alloc where subnet=? group by type";
    $cid = $db->SQL_OpenQuery( $qry, $subnet )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $type, $count ) = $db->SQL_FetchRow($cid) ) {
        $counts{$type} = $count;
    }
    $db->SQL_CloseQuery($cid);

    return %counts;
}

# Begin-Doc
# Name: GetFreeAddresses
# Type: method
# Description: Returns list of unused addresses for a given subnet
# Syntax: @addresses = $obj->GetFreeAddresses($subnet);
# End-Doc
sub GetFreeAddresses {
    my $self   = shift;
    my $subnet = shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @res;

    $qry
        = "select a.ip from ip_alloc a left outer join dns_a b on (a.ip = b.address) where "
        . " a.subnet=?"
        . " and a.type='static' "
        . " and b.address is null";
    $cid = $db->SQL_OpenQuery( $qry, $subnet )
        || $db->SQL_Error($qry) && return undef;

    while ( my ($ip) = $db->SQL_FetchRow($cid) ) {
        push( @res, $ip );
    }
    $db->SQL_CloseQuery($cid);

    return @res;
}

# Begin-Doc
# Name: IPToInteger
# Type: method
# Description: Returns integer form of IP address
# Syntax: $int = $obj->IPToInteger($addr);
# End-Doc
sub IPToInteger {
    my $self = shift;
    my $ip   = shift;

    my @ip = split( /\./, $ip );
    my $res = $ip[0] * 256 * 256 * 256 + $ip[1] * 256 * 256 + $ip[2] * 256 + $ip[3];

    return $res;
}

# Begin-Doc
# Name: IntegerToIP
# Type: method
# Description: Returns dotted quad netmask from a integer IP
# Syntax: $ip = $obj->IntegerToIP($int);
# End-Doc
sub IntegerToIP {
    my $self = shift;
    my $i    = int(shift);

    my ( $a, $b, $c, $d ) = unpack( 'C4', pack( 'N', $i ) );

    return sprintf( "%d.%d.%d.%d", $a, $b, $c, $d );
}

# Begin-Doc
# Name: BitsToMask
# Type: method
# Description: Returns dotted quad netmask from a /bits notation
# Syntax: $mask = $obj->BitsToMask($bits);
# End-Doc
sub BitsToMask {
    my $self = shift;
    my $bits = int(shift);

    if ( $bits < 1 || $bits > 31 ) {
        return undef;
    }

    my $mask = 0xffffffff;
    $mask = $mask << ( 32 - $bits );

    return $self->IntegerToIP($mask);
}

# Begin-Doc
# Name: BitsToWildcard
# Type: method
# Description: Returns dotted quad wildcard from a /bits notation
# Syntax: $mask = $obj->BitsToWildcard($bits);
# End-Doc
sub BitsToWildcard {
    my $self = shift;
    my $bits = int(shift);

    if ( $bits < 1 || $bits > 31 ) {
        return undef;
    }

    my $wc = 0xffffffff;
    $wc = $wc >> $bits;

    return $self->IntegerToIP($wc);
}

# Begin-Doc
# Name: MaskToBits
# Type: method
# Description: Returns number of 1 bits in a netmask
# Syntax: $bits = $obj->MaskToBits($mask);
# End-Doc
sub MaskToBits {
    my $self    = shift;
    my $mask    = shift;
    my $maskint = $self->IPToInteger($mask);
    my $bits    = 0;
    for ( my $i = 0; $i <= 31; $i++ ) {
        if ( $maskint & ( 1 << $i ) ) {
            $bits++;
        }
    }
    return $bits;
}

# Begin-Doc
# Name: GetDynamicRanges
# Type: method
# Description: Returns array of dynamic address ranges for a subnet
# Syntax: @ranges = $obj->GetDynamicRanges($subnet);
# End-Doc
sub GetDynamicRanges {
    my $self   = shift;
    my $subnet = shift;

    return $self->GetIPRanges( $subnet, "dynamic" );
}

# Begin-Doc
# Name: GetIPRanges
# Type: method
# Description: Returns array of address ranges of a particular type for a subnet
# Syntax: @ranges = $obj->GetIPRanges($subnet, $type);
# End-Doc
sub GetIPRanges {
    my $self   = shift;
    my $subnet = shift;
    my $type   = shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @ranges;

    my @addresses = $self->NetworkSort( $self->GetAllocatedAddresses( $subnet, $type ) );

    my $firstip = "";
    my $lastip  = "";
    my $lastint = 0;

    foreach my $addr (@addresses) {
        my $thisint = 0;

        if ( !$firstip ) {
            $firstip = $addr;
            $lastip  = $firstip;
            $lastint = $self->IPToInteger($lastip);
        }
        else {
            my $addrint = $self->IPToInteger($addr);
            if ( $addrint != ( $lastint + 1 ) ) {
                push( @ranges, [ $firstip, $lastip ] );
                $firstip = $addr;
            }
            $lastip  = $addr;
            $lastint = $addrint;
        }
    }

    if ($lastip) {
        push( @ranges, [ $firstip, $lastip ] );
    }

    return @ranges;
}

# Begin-Doc
# Name: ClearCache
# Type: method
# Description: Clears caches of VLAN and Subnet information
# Syntax: $obj->ClearCache()
# Comments: removes cache of vlan and subnet information
# End-Doc
sub ClearCache {
    my $self = shift;

    delete $self->{vlans};
    delete $self->{subnets};
}

# Begin-Doc
# Name: GetVLANs
# Type: method
# Description: Returns data for all vlan
# Syntax: $vlaninfo = $obj->GetVLANs();
# Comments: caches vlan info details for fast repeated lookup
# End-Doc
sub GetVLANs {
    my $self = shift;
    my $db   = $self->{db};
    my ( $qry, $cid );
    my $res = {};

    if ( $self->{vlans} ) {
        return $self->{vlans};
    }

    $qry = "select vlan,name,notes from vlans";
    $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && return undef;

    while ( my ( $vlan, $name, $notes ) = $db->SQL_FetchRow($cid) ) {
        my $tmp = {};
        $tmp->{name}  = $name;
        $tmp->{notes} = $notes;
        $res->{$vlan} = $tmp;
    }
    $db->SQL_CloseQuery($cid);

    $self->{vlans} = $res;

    return $res;
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
    my $db   = $self->{db};

    if ( $self->{subnets} ) {
        return $self->{subnets};
    }

    my $util = $self->{util};

    my $qry = "select subnet,description,mask,vlan,gateway,template,notes from subnets";
    my $cid = $db->SQL_OpenQuery($qry)
        || $db->SQL_Error($qry) && return undef;

    my $res = {};
    while ( my ( $subnet, $desc, $mask, $vlan, $gateway, $tmpl, $notes ) = $db->SQL_FetchRow($cid) ) {
        my $tmp      = {};
        my $subnetip = $subnet;

        $res->{$subnet} = $tmp;
        $subnetip =~ s|/.*||gio;
        $subnetip = $util->CondenseIP($subnetip);

        $tmp->{description} = $desc;
        $tmp->{mask}        = $mask;
        $tmp->{vlan}        = $vlan;
        $tmp->{ip}          = $subnetip;
        $tmp->{template}    = $tmpl || "standard";

        $tmp->{gateway}                          = $gateway;
        $tmp->{notes}                            = $notes;
        $tmp->{gateways}->{$gateway}->{priority} = 50;
    }
    $db->SQL_CloseQuery($cid);

    $self->{subnets} = $res;
    return $res;
}

# Begin-Doc
# Name: NetworkSort
# Type: method
# Description: Sorts an array according to network address
# Syntax: @list = $obj->NetworkSort(@list);
# End-Doc
sub NetworkSort {
    my $self  = shift;
    my @items = @_;

    return sort {
        my @aa = split( /[\.\/]/, $a );
        my @bb = split( /[\.\/]/, $b );
        return (   ( $aa[0] <=> $bb[0] )
                || ( $aa[1] <=> $bb[1] )
                || ( $aa[2] <=> $bb[2] )
                || ( $aa[3] <=> $bb[3] )
                || ( $aa[4] <=> $bb[4] ) );
    } @items;
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

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "update ip_alloc set host='' where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);
}

# Begin-Doc
# Name: MaskAddress
# Type: method
# Description: Masks an address with a given netmask
# Syntax: $maskedaddr = $obj->MaskAddress($addr, $mask);
# End-Doc
sub MaskAddress {
    my $self = shift;
    my $addr = shift;
    my $mask = shift;

    my $maskint = $self->IPToInteger($mask);
    my $addrint = $self->IPToInteger($addr);

    return $self->IntegerToIP( $addrint & $maskint );
}

# Begin-Doc
# Name: MakeBroadcastAddress
# Type: method
# Description: Calculates the broadcast address for a subnet given mask
# Syntax: $bcaddr = $obj->MakeBroadcastAddress($sn, $mask);
# End-Doc
sub MakeBroadcastAddress {
    my $self   = shift;
    my $subnet = shift;
    my $mask   = shift;

    my $maskint   = $self->IPToInteger($mask);
    my $subnetint = $self->IPToInteger($subnet);

    my $bcint = $subnetint | ~$maskint;
    my $bc    = $self->IntegerToIP($bcint);

    return $bc;
}

# Begin-Doc
# Name: MakeGatewayAddress
# Type: method
# Description: Calculates the standard gateway (bc-1) address for a subnet given mask
# Syntax: $gwaddr = $obj->MakeGatewayAddress($sn, $mask);
# End-Doc
sub MakeGatewayAddress {
    my $self   = shift;
    my $subnet = shift;
    my $mask   = shift;

    my $maskint   = $self->IPToInteger($mask);
    my $subnetint = $self->IPToInteger($subnet);

    my $bcint = $subnetint | ~$maskint;
    my $gwint = $bcint & ~0x0000001;

    my $gw = $self->IntegerToIP($gwint);

    return $gw;
}

# Begin-Doc
# Name: GenerateAddresses
# Type: method
# Description: Generates a list of all addresses that should be in a subnet with a given mask
# Syntax: @addrs = $obj->GenerateAddresses($subnet_base_ip, $mask);
# End-Doc
sub GenerateAddresses {
    my $self   = shift;
    my $subnet = shift;
    my $mask   = shift;

    my $maskedsn = $self->MaskAddress( $subnet, $mask );
    if ( $maskedsn ne $subnet ) {
        return ();
    }

    my $sint = $self->IPToInteger($subnet);

    my $bc = $self->MakeBroadcastAddress( $subnet, $mask );
    my $bcint = $self->IPToInteger($bc);

    my @addrs = ();
    for ( my $i = $sint; $i <= $bcint; $i++ ) {
        push( @addrs, $self->IntegerToIP($i) );
    }

    return @addrs;
}

# Begin-Doc
# Name: CheckSubnetOverlap
# Type: method
# Description: Checks to see if a new subnet would overlap with existing
# Syntax: $obj->CheckSubnetOverlap($subnet_base_ip, $mask);
# End-Doc
sub CheckSubnetOverlap {
    my $self   = shift;
    my $baseip = shift;
    my $mask   = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    my $subnets = $self->GetSubnets();

    my $maskedsn = $self->MaskAddress( $baseip, $mask );
    if ( $maskedsn ne $baseip ) {
        return "baseip doesn't match mask, cannot check for overlap";
    }

    my $sn;
    foreach $sn ( keys %{$subnets} ) {
        my $snip   = $subnets->{$sn}->{ip};
        my $snmask = $subnets->{$sn}->{mask};

        my $masked_old = $self->MaskAddress( $snip,   $mask );
        my $masked_new = $self->MaskAddress( $baseip, $snmask );

        if ( $masked_old eq $baseip || $masked_new eq $snip ) {
            return "overlaps with $snip/$snmask";
        }
    }

    return 0;
}

# Begin-Doc
# Name: DeleteVLAN
# Type: method
# Description: Deletes a given vlan
# Syntax: $obj->DeleteVLAN($vlan);
# End-Doc
sub DeleteVLAN {
    my $self = shift;
    my $vlan = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    $qry = "delete from vlans where vlan=?";
    $db->SQL_ExecQuery( $qry, $vlan )
        || $db->SQL_Error($qry) && return "failed to delete vlan";
}

# Begin-Doc
# Name: ChangeVLAN
# Type: method
# Description: Updates a vlan with new name
# Syntax: $obj->ChangeVLAN($vlan, $name, $notes);
# End-Doc
sub ChangeVLAN {
    my $self  = shift;
    my $vlan  = shift;
    my $name  = shift;
    my $notes = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    $qry = "update vlans set name=?,notes=? where vlan=?";
    $db->SQL_ExecQuery( $qry, $name, $notes, $vlan )
        || $db->SQL_Error($qry) && return "failed to update vlan";
}

# Begin-Doc
# Name: CreateVLAN
# Type: method
# Description: Creates a new vlan with a given name
# Syntax: $obj->CreateVLAN($vlan, $name, $notes);
# End-Doc
sub CreateVLAN {
    my $self  = shift;
    my $vlan  = shift;
    my $name  = shift;
    my $notes = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    $qry = "insert into vlans(vlan, name, notes) values (?,?,?)";
    $db->SQL_ExecQuery( $qry, $vlan, $name, $notes )
        || $db->SQL_Error($qry) && return "failed to insert vlan";
}

# Begin-Doc
# Name: ChangeSubnet
# Type: method
# Description: Updates a subnet with new description, vlan, and template
# Syntax: $obj->ChangeSubnet($subnet, $description, $vlan, $template, $notes);
# End-Doc
sub ChangeSubnet {
    my $self        = shift;
    my $subnet      = shift;
    my $description = shift;
    my $vlan        = shift;
    my $tmpl        = shift;
    my $notes       = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    $qry = "update subnets set description=?,vlan=?,template=?, notes=? where subnet=?";
    $db->SQL_ExecQuery( $qry, $description, $vlan, $tmpl, $notes, $subnet )
        || $db->SQL_Error($qry) && return "failed to update sn";
}

# Begin-Doc
# Name: CreateSubnet
# Type: method
# Description: Creates a new subnet with a given mask
# Syntax: $obj->CreateSubnet($subnet_base_ip, $mask, $description, $vlan, $tmpl, $notes);
# End-Doc
sub CreateSubnet {
    my $self        = shift;
    my $subnet      = shift;
    my $mask        = shift;
    my $description = shift;
    my $vlan        = shift;
    my $tmpl        = shift;
    my $notes       = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    my $maskedsn = $self->MaskAddress( $subnet, $mask );
    if ( $maskedsn ne $subnet ) {
        return ();
    }

    my $gw = $self->MakeGatewayAddress( $subnet, $mask );

    my @addrs     = $self->GenerateAddresses( $subnet, $mask );
    my $firstaddr = $addrs[0];
    my $lastaddr  = $addrs[$#addrs];

    my $subnetname = $subnet . "/" . $self->MaskToBits($mask);

    $qry = "insert into subnets(subnet,description,mask,vlan,gateway,template,notes) values (?,?,?,?,?,?,?)";
    $db->SQL_ExecQuery( $qry, $subnetname, $description, $mask, $vlan, $gw, $tmpl, $notes )
        || $db->SQL_Error($qry) && return "failed to insert sn";

    $qry = "lock tables ip_alloc write";
    $db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && return "failed to lock table";

    $qry = "insert into ip_alloc(ip,subnet,type) values (?,?,?)";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return "failed to open insert qry";
    foreach my $addr (@addrs) {
        my $type = "static";
        if ( $addr eq $firstaddr || $addr eq $lastaddr ) {
            $type = "special";
        }
        $db->SQL_ExecQuery( $cid, $addr, $subnetname, $type )
            || $db->SQL_Error( $qry . ": addr=$addr sn=$subnetname type=$type" );
    }
    $db->SQL_CloseQuery($cid);

    $qry = "unlock tables";
    $db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && return "failed to unlock tables";
}

1;
