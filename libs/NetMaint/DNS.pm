# Begin-Doc
# Name: NetMaint::DNS
# Type: module
# Description: object to manage access to dns information
# End-Doc

package NetMaint::DNS;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use NetMaint::Config;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Logging;
require NetMaint::LastTouch;
require NetMaint::DBCache;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Block any updates
our $block_updates = 0;

# Keep track of whether any updates occurred.
our $blocked_updates = 0;

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::DNS()
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

    # If we're blocking updates, make note, and return
    if ($block_updates) {
        $blocked_updates++;
        return;
    }

    $self->{log}->Log( action => "triggered dns update", );

    foreach my $server (@$NETDB_DNS_SERVERS) {
        my $sock = IO::Socket::INET->new(
            Timeout  => 2,
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
# Name: Get_Host_Zone
# Type: method
# Description: Returns best match zone name for a given hostname
# Syntax: $zone = $obj->Get_Host_Zone($host);
# End-Doc
sub Get_Host_Zone {
    my $self = shift;
    my $host = shift;

    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    #
    # Loop through all zones, finding best (longest) match
    #
    $qry = "select zone from dns_soa";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery($cid) || $db->SQL_Error($qry) && return undef;

    my $cur_best_zone = undef;

    my $l_host = length($host);
    while ( my ($zone) = $db->SQL_FetchRow($cid) ) {
        if ( $host eq $zone ) {
            $cur_best_zone = $zone;
            last;
        }

        my $idx = index( $host, "." . $zone );
        my $l_zone = length($zone);

        # ends with
        if ( ( $idx >= 0 ) && $idx == ( $l_host - $l_zone - 1 ) ) {
            if ( $l_zone > length($cur_best_zone) ) {
                $cur_best_zone = $zone;
            }
        }
    }

    return $cur_best_zone;
}

# Begin-Doc
# Name: Get_A_Records
# Type: method
# Description: Returns array of A records as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_A_Records($host);
# End-Doc
sub Get_A_Records {
    my $self = shift;
    my $host = shift;

    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select zone,ttl,address,mtime,ctime,dynamic from dns_a where name=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $host )
        || $db->SQL_Error( $qry . " ($host)" ) && return undef;

    while ( my ( $zone, $tty, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $host,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Get_Static_A_Records
# Type: method
# Description: Returns array of A records as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_Static_A_Records($host);
# End-Doc
sub Get_Static_A_Records {
    my $self = shift;
    my $host = shift;

    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select zone,ttl,address,mtime,ctime,dynamic from dns_a where dynamic=0 and name=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $host )
        || $db->SQL_Error( $qry . " ($host)" ) && return undef;

    while ( my ( $zone, $tty, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $host,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Get_Static_AAAA_Records
# Type: method
# Description: Returns array of AAAA records as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_Static_AAAA_Records($host);
# End-Doc
sub Get_Static_AAAA_Records {
    my $self = shift;
    my $host = shift;

    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select zone,ttl,address,mtime,ctime,dynamic from dns_aaaa where dynamic=0 and name=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $host )
        || $db->SQL_Error( $qry . " ($host)" ) && return undef;

    while ( my ( $zone, $tty, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $host,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Get_Static_PTR_Records
# Type: method
# Description: Returns array of A records as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_Static_PTR_Records($host);
# End-Doc
sub Get_Static_PTR_Records {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select zone,ttl,name,address,mtime,ctime,dynamic from dns_ptr where dynamic=0 and address=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $zone, $ttl, $name, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $name,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Count_Static_A_Records
# Type: method
# Description: Returns count of static A records for a host
# Syntax: $cnt = $obj->Count_Static_A_Records($host);
# End-Doc
sub Count_Static_A_Records {
    my $self = shift;
    my $host = shift;

    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my ( $qry, $cid );

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select count(*) from dns_a where dynamic=0 and name=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $host )
        || $db->SQL_Error( $qry . " ($host)" ) && return undef;
    my ($cnt) = $db->SQL_FetchRow($cid);

    return $cnt;
}

# Begin-Doc
# Name: Search_A_Records_Address
# Type: method
# Description: Returns array of A records with particular address
# Syntax: @records = $obj->Search_A_Records_Address($address);
# End-Doc
sub Search_A_Records_Address {
    my $self = shift;
    my $addr = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$addr ) {
        return undef;
    }

    $qry = "select name,zone,ttl,address,mtime,ctime,dynamic from dns_a where address like ?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, "%" . $addr . "%" )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $host, $zone, $ttl, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $host,
                ttl     => $ttl,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Search_PTR_Records_IP_Exact
# Type: method
# Description: Returns array of PTR records with particular ip addr  as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Search_PTR_Records_IP_Exact($ip);
# End-Doc
sub Search_PTR_Records_IP_Exact {
    my $self = shift;
    my $addr = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$addr ) {
        return undef;
    }

    my $util     = $self->{util};
    my $arpaaddr = $util->IPToARPA($addr);

    $qry = "select name,zone,ttl,address,mtime,ctime,dynamic from dns_ptr where name=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $arpaaddr )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $name, $zone, $ttl, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $name,
                ttl     => $ttl,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Search_A_Records_Address_Exact
# Type: method
# Description: Returns array of A records with particular address  as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Search_A_Records_Address_Exact($address);
# End-Doc
sub Search_A_Records_Address_Exact {
    my $self = shift;
    my $addr = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$addr ) {
        return undef;
    }

    $qry = "select name,zone,ttl,address,mtime,ctime,dynamic from dns_a where address=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $addr ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $host, $zone, $tty, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $host,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: GetDomains
# Type: method
# Description: Returns hash of subdomain names and descriptions
# Syntax: %domains = $obj->GetDomains();
# End-Doc
sub GetDomains {
    my $self = shift;
    my $db   = $self->{db};
    my ( $qry, $cid );
    my %domains;

    $qry = "select domain,description from domains";
    $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && return undef;
    while ( my ( $domain, $desc ) = $db->SQL_FetchRow($cid) ) {
        $domains{$domain} = $desc;
    }
    $db->SQL_CloseQuery($cid);

    return %domains;
}

# Begin-Doc
# Name: Get_MX_Records
# Type: method
# Description: Returns array of MX records as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_MX_Records($host);
# End-Doc
sub Get_MX_Records {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select zone,ttl,priority,address,mtime,ctime,dynamic from dns_mx where name=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $zone, $tty, $priority, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone     => $zone,
                name     => $host,
                priority => $priority,
                address  => $address,
                mtime    => $mtime,
                ctime    => $ctime,
                dynamic  => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Get_CNAME_Records
# Type: method
# Description: Returns array of CNAME records as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_CNAME_Records($host);
# End-Doc
sub Get_CNAME_Records {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$host || ( lc $host ne $host ) ) {
        return undef;
    }

    $qry = "select zone,ttl,address,mtime,ctime,dynamic from dns_cname where name=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;

    while ( my ( $zone, $tty, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $host,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Get_CNAME_Records_Target
# Type: method
# Description: Returns array of CNAME records pointing at a given target host as hashes with zone, name, address, etc. fields
# Syntax: @records = $obj->Get_CNAME_Records_Target($host);
# End-Doc
sub Get_CNAME_Records_Target {
    my $self   = shift;
    my $target = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @recs;

    if ( !$target || ( lc $target ne $target ) ) {
        return undef;
    }

    $qry = "select name,zone,ttl,address,mtime,ctime,dynamic from dns_cname where address=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $target )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $name, $zone, $tty, $address, $mtime, $ctime, $dynamic ) = $db->SQL_FetchRow($cid) ) {
        push(
            @recs,
            {   zone    => $zone,
                name    => $name,
                address => $address,
                mtime   => $mtime,
                ctime   => $ctime,
                dynamic => $dynamic,
            }
        );
    }

    return @recs;
}

# Begin-Doc
# Name: Delete_CNAME_Record
# Type: method
# Description: Deletes CNAME record for a host
# Syntax: $obj->Delete_CNAME_Record($host);
# End-Doc
sub Delete_CNAME_Record {
    my $self = shift;
    my $host = lc shift;
    my $qry;

    my $db = $self->{db};

    $qry = "delete from dns_cname where name=?";
    $db->SQL_ExecQuery( $qry, $host )
        || $db->SQL_Error($qry) && return "sql error";

    $self->{log}->Log(
        action => "deleted host cname record",
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Update_CNAME_Record
# Type: method
# Description: Adds or updates CNAME record for a host
# Syntax: $obj->Update_CNAME_Record($host, $target);
# Comments: parms has keys host, target
# End-Doc
sub Update_CNAME_Record {
    my $self   = shift;
    my $host   = lc shift;
    my $target = shift;
    my $qry;

    my $db = $self->{db};

    my $zone = $self->Get_Host_Zone($host);
    if ( !$zone ) {
        print "Unable to handle cname update request for ($host).\n";
        return;
    }

    $self->{touch}->UpdateLastTouch( host => $host );

    $qry = "delete from dns_cname where name=?";
    $db->SQL_ExecQuery( $qry, $host )
        || $db->SQL_Error($qry) && return "sql error";

    $qry = "insert into dns_cname(zone,ttl,name,address,mtime,ctime,dynamic) values (?,0,?,?,now(),now(),0)";
    $db->SQL_ExecQuery( $qry, $zone, $host, $target )
        || $db->SQL_Error($qry) && return "sql error";

    $self->{log}->Log(
        action => "updated host cname record",
        host   => $host,
        target => $target,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Add_Dynamic_HostIP
# Type: method
# Description: Adds dynamic dns records for an IP addr
# Syntax: $obj->Add_Dynamic_HostIP($host,$ip);
# End-Doc
sub Add_Dynamic_HostIP {
    my $self    = shift;
    my $host    = shift;
    my $ip      = shift;
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my $zone = $self->Get_Host_Zone($host);
    if ( !$zone ) {
        print "Unable to handle dynamic hostip request for ($host).\n";
        return;
    }

    my $qry;
    my $cid;
    my $util = $self->{util};

    $ip = $util->CondenseIP($ip);
    my $arpa     = $util->IPToARPA($ip);
    my $arpazone = $util->IPToARPAZone($ip);

    # Clean up just in case
    $self->Delete_Dynamic_ByIP($ip);

    $self->{touch}->UpdateLastTouch( host => $host, ip => $ip );

    $qry = "insert into dns_a(zone,ttl,name,address,mtime,ctime,dynamic) values (?,0,?,?,now(),now(),1)";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $zone, $host, $ip );

    # ignore errors, should check specifically for dup and ignore that

    # Update the namesort field for use when sorting the records in the PTR zones.
    my @tmpip = split( /\./, $ip );
    my $namesort = $tmpip[0] * 256 * 256 * 256 + $tmpip[1] * 256 * 256 + $tmpip[2] * 256 + $tmpip[3];

    $qry = "insert into dns_ptr(zone,ttl,name,namesort,address,mtime,ctime,dynamic) "
        . "values (?,0,?,?,?,now(),now(),1)";
    $cid = $dbcache->open($qry);

    #print "inserting arpa for $arpazone/$arpa/$host\n";
    $db->SQL_ExecQuery( $cid, $arpazone, $arpa, $namesort, $host );

    $self->{log}->Log(
        action => "added dynamic host/ip record",
        ip     => $ip,
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: UpdateNamesort
# Type: method
# Description: Updates namesort info for an IP
# Syntax: $obj->UpdateNamesort($ip_or_inaddr);
# End-Doc
sub UpdateNamesort {
    my $self         = shift;
    my $ip_or_inaddr = shift;
    my $db           = $self->{db};
    my $util         = $self->{util};
    my $ip           = $ip_or_inaddr;

    if ( $ip_or_inaddr =~ /in-addr/o ) {
        $ip = $util->ARPAToIP($ip_or_inaddr);
    }

    my $arpa = $util->IPToARPA($ip);

    my @tmpip = split( /\./, $ip );
    my $namesort = $tmpip[0] * 256 * 256 * 256 + $tmpip[1] * 256 * 256 + $tmpip[2] * 256 + $tmpip[3];

    my $qry = "update dns_ptr set namesort=? where name=?";
    $db->SQL_ExecQuery( $qry, $namesort, $arpa ) || $db->SQL_Error($qry);
}

# Begin-Doc
# Name: Delete_Dynamic_ByIP
# Type: method
# Description: Deletes any dynamic dns records for an IP addr
# Syntax: $obj->Delete_Dynamic_ByIP($ip);
# End-Doc
sub Delete_Dynamic_ByIP {
    my $self    = shift;
    my $ip      = shift;
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};
    my $qry;
    my $cid;
    my $arpa;

    my $util = $self->{util};

    $ip   = $util->CondenseIP($ip);
    $arpa = $util->IPToARPA($ip);

    $qry = "delete from dns_a where dynamic=1 and address=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $ip ) || $db->SQL_Error($qry);

    $qry = "delete from dns_ptr where dynamic=1 and name=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $qry, $arpa ) || $db->SQL_Error($qry);

    $self->{log}->Log(
        action => "deleted dynamic host/ip records",
        ip     => $ip,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Delete_Dynamic_ByHostFwdOnly
# Type: method
# Description: Deletes any dynamic dns records for an IP addr
# Syntax: $obj->Delete_Dynamic_ByNameFwdOnly($host);
# End-Doc
sub Delete_Dynamic_ByHostFwdOnly {
    my $self    = shift;
    my $host    = shift;
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};
    my $qry;
    my $cid;

    $qry = "delete from dns_a where dynamic=1 and name=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry);

    $self->{log}->Log(
        action => "deleted dynamic host/ip records",
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Delete_PTR_ByHostIP
# Type: method
# Description: Deletes any ptr records for an IP addr and host
# Syntax: $obj->Delete_PTR_ByHostIP($host, $ip);
# End-Doc
sub Delete_PTR_ByHostIP {
    my $self = shift;
    my $host = shift;
    my $ip   = shift;
    my $db   = $self->{db};
    my $qry;
    my $arpa;

    my $util = $self->{util};

    $ip   = $util->CondenseIP($ip);
    $arpa = $util->IPToARPA($ip);

    $qry = "delete from dns_ptr where name=? and address=?";
    $db->SQL_ExecQuery( $qry, $arpa, $host ) || $db->SQL_Error($qry);

    $self->{log}->Log(
        action => "deleted static ptr record",
        ip     => $ip,
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Delete_A_ByHostIP
# Type: method
# Description: Deletes any A records for an IP addr and host
# Syntax: $obj->Delete_A_ByHostIP($host, $ip);
# End-Doc
sub Delete_A_ByHostIP {
    my $self = shift;
    my $host = shift;
    my $ip   = shift;
    my $db   = $self->{db};
    my $qry;
    my $arpa;

    my $util = $self->{util};

    my $cip = $util->CondenseIP($ip);

    $qry = "delete from dns_a where name=? and (address=? or address=?)";
    $db->SQL_ExecQuery( $qry, $host, $ip, $cip ) || $db->SQL_Error($qry);

    $self->{log}->Log(
        action => "deleted static a record",
        ip     => $ip,
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Delete_AAAA_ByHostIP
# Type: method
# Description: Deletes any AAAA records for an IP addr and host
# Syntax: $obj->Delete_AAAA_ByHostIP($host, $ip);
# End-Doc
sub Delete_AAAA_ByHostIP {
    my $self = shift;
    my $host = shift;
    my $ip   = shift;
    my $db   = $self->{db};
    my $qry;
    my $arpa;

    my $util = $self->{util};

    my $cip = $util->CondenseIPv6($ip);

    $qry = "delete from dns_aaaa where name=? and (address=? or address=?)";
    $db->SQL_ExecQuery( $qry, $host, $ip, $cip ) || $db->SQL_Error($qry);

    $self->{log}->Log(
        action => "deleted static aaaa record",
        ip     => $ip,
        host   => $host,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Add_Static_PTR
# Type: method
# Description: Adds or updates PTR record for a ip & host
# Syntax: $obj->Add_Static_PTR($ip, $host);
# Comments: parms has keys host, target
# End-Doc
sub Add_Static_PTR {
    my $self = shift;
    my $ip   = shift;
    my $host = lc shift;
    my $util = $self->{util};
    my $qry;

    my $db = $self->{db};

    my $zone = $self->Get_Host_Zone($host);
    if ( !$zone ) {
        print "Unable to handle static ptr update request for ($host).\n";
        return;
    }

    my $arpa     = $util->IPToARPA($ip);
    my $arpazone = $util->IPToARPAZone($ip);

    $self->{touch}->UpdateLastTouch( host => $host, ip => $ip );

    $qry = "delete from dns_ptr where address=? and name=?";
    $db->SQL_ExecQuery( $qry, $host, $arpa )
        || $db->SQL_Error($qry) && return "sql error";

    $qry = "insert into dns_ptr(zone,ttl,name,address,mtime,ctime,dynamic) values (?,0,?,?,now(),now(),0)";
    $db->SQL_ExecQuery( $qry, $arpazone, $arpa, $host )
        || $db->SQL_Error($qry) && return "sql error";

    $self->{log}->Log(
        action => "added static host ptr record",
        host   => $host,
        ip     => $ip,
    );

    $self->UpdateNamesort($arpa);

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Add_Static_A
# Type: method
# Description: Adds or updates A record for a ip & host
# Syntax: $obj->Add_Static_A($host, $ip);
# End-Doc
sub Add_Static_A {
    my $self = shift;
    my $host = lc shift;
    my $ip   = shift;
    my $qry;

    my $db = $self->{db};

    my $zone = $self->Get_Host_Zone($host);
    if ( !$zone ) {
        print "Unable to handle ptr addr update request for ($host).\n";
        return;
    }

    $self->{touch}->UpdateLastTouch( host => $host, ip => $ip );

    $qry = "delete from dns_a where address=? and name=?";
    $db->SQL_ExecQuery( $qry, $ip, $host )
        || $db->SQL_Error($qry) && return "sql error";

    $qry = "insert into dns_a(zone,ttl,name,address,mtime,ctime,dynamic) values (?,0,?,?,now(),now(),0)";
    $db->SQL_ExecQuery( $qry, $zone, $host, $ip )
        || $db->SQL_Error($qry) && return "sql error";

    $self->{log}->Log(
        action => "added static host a record",
        host   => $host,
        ip     => $ip,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: Add_Static_AAAA
# Type: method
# Description: Adds or updates AAAA record for a ip & host
# Syntax: $obj->Add_Static_AAAA($host, $ip);
# End-Doc
sub Add_Static_AAAA {
    my $self = shift;
    my $host = lc shift;
    my $ip   = shift;
    my $qry;

    my $db = $self->{db};

    my $zone = $self->Get_Host_Zone($host);
    if ( !$zone ) {
        print "Unable to handle ptr addr update request for ($host).\n";
        return;
    }

    $self->{touch}->UpdateLastTouch( host => $host, ip => $ip );

    $qry = "delete from dns_aaaa where address=? and name=?";
    $db->SQL_ExecQuery( $qry, $ip, $host )
        || $db->SQL_Error($qry) && return "sql error";

    $qry = "insert into dns_aaaa(zone,ttl,name,address,mtime,ctime,dynamic) values (?,0,?,?,now(),now(),0)";
    $db->SQL_ExecQuery( $qry, $zone, $host, $ip )
        || $db->SQL_Error($qry) && return "sql error";

    $self->{log}->Log(
        action => "added static host aaaa record",
        host   => $host,
        ip     => $ip,
    );

    $self->TriggerUpdate();
}

# Begin-Doc
# Name: DeleteHost
# Type: method
# Description: Deletes all dns data associated with a host
# Syntax: $obj->DeleteHost($host);
# End-Doc
sub DeleteHost {
    my $self = shift;
    my $host = lc shift;

    my $db = $self->{db};

    my ( $qry, $cid );

    foreach my $tbl ( "dns_a", "dns_cname", "dns_mx", "dns_txt" ) {
        $qry = "delete from $tbl where name=?";
        $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);
    }

    $qry = "delete from dns_ptr where address=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $self->{log}->Log(
        action => "deleted host",
        host   => $host,
    );

    $self->TriggerUpdate();
}

1;
