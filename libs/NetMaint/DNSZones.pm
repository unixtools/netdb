# Begin-Doc
# Name: NetMaint::DNSZones
# Type: module
# Description: object to manage access to dns information
# End-Doc

package NetMaint::DNSZones;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use UMR::UsageLogger;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Error;

our $error = new NetMaint::Error;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::DNSZones()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}   = new NetMaint::DB;
    $tmp->{util} = new NetMaint::Util;

    &LogAPIUsage();

    return bless $tmp, $class;
}

# Begin-Doc
# Name: GetZones
# Type: method
# Description: Returns array of zone names
# Syntax: @zones = $obj->GetZones()
# End-Doc
sub GetZones {
    my $self = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my @zones;

    $qry = "select distinct(lower(zone)) from dns_soa";
    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query for zone list");
        return undef;
    }

    while ( my ($zone) = $db->SQL_FetchRow($cid) ) {
        if ( $db->SQL_ErrorCode() ) {
            $error->set("sql error fetching row in zone list");
            last;
        }
        push( @zones, $zone );
    }
    $db->SQL_CloseQuery($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error fetching row in zone list");
    }

    return @zones;
}

# Begin-Doc
# Name: UpdateAllSOA
# Type: method
# Description: Updates all SOA records
# Syntax: $obj->UpdateAllSOA()
# End-Doc
sub UpdateAllSOA {
    my $self = shift;
    my $db   = $self->{db};

    my $qry = "update dns_soa set serial=serial+1,mtime=now()";
    unless ( $db->SQL_ExecQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error updating serial numbers");
    }
}

# Begin-Doc
# Name: GetSignableZones
# Type: method
# Description: Returns array of zones that should be signed
# Syntax: @zones = $obj->GetSignableZones()
# End-Doc
sub GetSignableZones {
    my $self = shift;
    my $db   = $self->{db};
    my @zones;

    # mod in last 10 minutes - since we rebuild at least that often
    my $cid;
    my $qry = "select distinct(lower(zone)) from dns_soa where signzone=1";

    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query for signable zones");
        return undef;
    }

    while ( my ($zone) = $db->SQL_FetchRow($cid) ) {
        if ( $db->SQL_ErrorCode() ) {
            $error->set("sql error fetching signable zone row");
            last;
        }
        push( @zones, $zone );
    }
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error fetching signable zone row");
    }
    $db->SQL_CloseQuery($cid);

    return @zones;
}

# Begin-Doc
# Name: GetChangedZones
# Type: method
# Description: Returns array of zones change recently
# Syntax: @zones = $obj->GetChangedZones()
# End-Doc
sub GetChangedZones {
    my $self = shift;
    my $db   = $self->{db};
    my @zones;

    # mod in last 10 minutes - since we rebuild at least that often
    my $cid;
    my $qry = "select distinct(lower(zone)) from dns_soa where unix_timestamp(now())-unix_timestamp(mtime) < 600";

    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query for changed zones");
        return undef;
    }

    while ( my ($zone) = $db->SQL_FetchRow($cid) ) {
        if ( $db->SQL_ErrorCode() ) {
            $error->set("sql error fetching changed zone row");
            last;
        }
        push( @zones, $zone );
    }
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error fetching changed zone row");
    }
    $db->SQL_CloseQuery($cid);

    return @zones;
}

# Begin-Doc
# Name: Format_Zone_Record
# Type: method
# Description: Returns string for a record to put in zone file
# Syntax: $string = $obj->Format_Zone_Record($hashref);
# End-Doc
sub Format_Zone_Record {
    my $self = shift;
    my $rec  = shift;
    my $res;

    my $type = uc $rec->{recordtype};

    if ( $type eq "A" ) {
        my $name = $rec->{name};
        my $addr = $rec->{address};
        return "${name}. IN A ${addr}";
    }
    elsif ( $type eq "AAAA" ) {
        my $name = $rec->{name};
        my $addr = $rec->{address};
        return "${name}. IN AAAA ${addr}";
    }
    elsif ( $type eq "SOA" ) {
        my $zone    = $rec->{zone};
        my $server  = $rec->{server};
        my $contact = $rec->{contact};
        my $serial  = int( $rec->{serial} );
        my $refresh = int( $rec->{refresh} );
        my $retry   = int( $rec->{retry} );
        my $expire  = int( $rec->{expire} );
        my $minttl  = int( $rec->{minttl} );

        return "${zone}. IN SOA ${server}. ${contact}. ( ${serial} ${refresh} ${retry} ${expire} ${minttl} )";
    }
    elsif ( $type eq "NS" ) {
        my $name = $rec->{name};
        my $addr = $rec->{address};
        my $ttl  = int( $rec->{ttl} ) || "";
        return "${name}. $ttl IN NS ${addr}.";
    }
    elsif ( $type eq "MX" ) {
        my $name = $rec->{name};
        my $addr = $rec->{address};
        my $pri  = int( $rec->{priority} );
        my $ttl  = int( $rec->{ttl} ) || "";
        return "${name}. $ttl IN MX ${pri} ${addr}.";
    }
    elsif ( $type eq "SRV" ) {
        my $name   = $rec->{name};
        my $addr   = $rec->{address};
        my $pri    = int( $rec->{priority} );
        my $weight = int( $rec->{weight} );
        my $port   = int( $rec->{port} );
        my $ttl    = int( $rec->{ttl} ) || "";
        return "${name}. $ttl IN SRV ${pri} ${weight} ${port} ${addr}.";
    }
    elsif ( $type eq "TXT" ) {
        my $name = $rec->{name};
        my $txt  = $rec->{txt};
        my $ttl  = int( $rec->{ttl} ) || "";
        return "${name}. $ttl IN TXT \"${txt}\"";
    }
    elsif ( $type eq "CNAME" ) {
        my $name    = $rec->{name};
        my $address = $rec->{address};
        my $ttl     = int( $rec->{ttl} ) || "";
        return "${name}. $ttl IN CNAME ${address}.";
    }
    elsif ( $type eq "PTR" ) {
        my $name    = $rec->{name};
        my $address = $rec->{address};
        my $ttl     = int( $rec->{ttl} ) || "";
        return "${name}. $ttl IN PTR ${address}.";
    }
    else {
        return "; unable to format record type ($type)";
    }
}

# Begin-Doc
# Name: Get_Zone_Records
# Type: method
# Description: Returns array ref of records of a given type in a zone
# Syntax: $records = $obj->Get_Zone_Records($zone, $type);
# End-Doc
sub Get_Zone_Records {
    my $self = shift;
    my $zone = shift;
    my $type = uc shift;

    if ( $type eq "A" ) {
        return $self->Get_Zone_A_Records($zone);
    }
    elsif ( $type eq "AAAA" ) {
        return $self->Get_Zone_AAAA_Records($zone);
    }
    elsif ( $type eq "SOA" ) {
        return $self->Get_Zone_SOA_Records($zone);
    }
    elsif ( $type eq "NS" ) {
        return $self->Get_Zone_NS_Records($zone);
    }
    elsif ( $type eq "MX" ) {
        return $self->Get_Zone_MX_Records($zone);
    }
    elsif ( $type eq "SRV" ) {
        return $self->Get_Zone_SRV_Records($zone);
    }
    elsif ( $type eq "TXT" ) {
        return $self->Get_Zone_TXT_Records($zone);
    }
    elsif ( $type eq "CNAME" ) {
        return $self->Get_Zone_CNAME_Records($zone);
    }
    elsif ( $type eq "PTR" ) {
        return $self->Get_Zone_PTR_Records($zone);
    }
    return ();
}

# Begin-Doc
# Name: Get_Zone_A_Records
# Type: method
# Description: Returns array of A records in a zone
# Syntax: @records = $obj->Get_Zone_A_Records($zone);
# End-Doc
sub Get_Zone_A_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select name,ttl,address from dns_a where zone=? order by name,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $name, $ttl, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "A",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_AAAA_Records
# Type: method
# Description: Returns array of AAAA records in a zone
# Syntax: @records = $obj->Get_Zone_AAAA_Records($zone);
# End-Doc
sub Get_Zone_AAAA_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select name,ttl,address from dns_aaaa where zone=? order by name,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $name, $ttl, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "AAAA",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_CNAME_Records
# Type: method
# Description: Returns array of CNAME records in a zone
# Syntax: @records = $obj->Get_Zone_CNAME_Records($zone);
# End-Doc
sub Get_Zone_CNAME_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select name,ttl,address from dns_cname where zone=? order by name,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }

    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $name, $ttl, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "CNAME",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_PTR_Records
# Type: method
# Description: Returns array of PTR records in a zone
# Syntax: @records = $obj->Get_Zone_PTR_Records($zone);
# End-Doc
sub Get_Zone_PTR_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select name,ttl,address from dns_ptr where zone=? order by namesort,name,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }

    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $name, $ttl, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "PTR",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_TXT_Records
# Type: method
# Description: Returns array of TXT records in a zone
# Syntax: @records = $obj->Get_Zone_TXT_Records($zone);
# End-Doc
sub Get_Zone_TXT_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select ttl,name,txt from dns_txt where zone=? order by name";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }

    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $ttl, $name, $txt ) = @$rref;

        push(
            @$recs,
            {   recordtype => "TXT",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                txt        => $txt,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_NS_Records
# Type: method
# Description: Returns array of NS records in a zone
# Syntax: @records = $obj->Get_Zone_NS_Records($zone);
# End-Doc
sub Get_Zone_NS_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select ttl,name,address from dns_ns where zone=? order by name,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }

    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $ttl, $name, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "NS",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_MX_Records
# Type: method
# Description: Returns array of MX records in a zone
# Syntax: @records = $obj->Get_Zone_MX_Records($zone);
# End-Doc
sub Get_Zone_MX_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select ttl,name,priority,address from dns_mx where zone=? order by name,priority,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }

    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $ttl, $name, $priority, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "MX",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                priority   => $priority,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_SRV_Records
# Type: method
# Description: Returns array of SRV records in a zone
# Syntax: @records = $obj->Get_Zone_SRV_Records($zone);
# End-Doc
sub Get_Zone_SRV_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry
        = "select ttl,name,priority,weight,port,address "
        . "from dns_srv where zone=?"
        . " order by name,priority,weight,port,address";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }

    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $ttl, $name, $priority, $weight, $port, $address ) = @$rref;

        push(
            @$recs,
            {   recordtype => "SRV",
                zone       => $zone,
                name       => $name,
                ttl        => $ttl,
                priority   => $priority,
                weight     => $weight,
                port       => $port,
                address    => $address,
            }
        );
    }

    return $recs;
}

# Begin-Doc
# Name: Get_Zone_SOA_Records
# Type: method
# Description: Returns array of SOA records in a zone
# Syntax: @records = $obj->Get_Zone_SOA_Records($zone);
# End-Doc
sub Get_Zone_SOA_Records {
    my $self = shift;
    my $zone = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $recs = [];

    if ( !$zone || ( lc $zone ne $zone ) ) {
        return undef;
    }

    $qry = "select ttl,server,contact,serial,refresh,retry,expire,minttl from dns_soa where zone=?";
    unless ( $cid = $db->SQL_OpenBoundQuery($qry) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    unless ( $db->SQL_ExecQuery( $cid, $zone ) ) {
        $db->SQL_Error($qry);
        $error->set("sql error opening query to fetch zone records");
        return undef;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    if ( $db->SQL_ErrorCode() ) {
        $error->set("sql error while fetching zone records");
    }
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $ttl, $server, $contact, $serial, $refresh, $retry, $expire, $minttl ) = @$rref;

        push(
            @$recs,
            {   recordtype => "SOA",
                zone       => $zone,
                ttl        => $ttl,
                server     => $server,
                contact    => $contact,
                serial     => $serial,
                refresh    => $refresh,
                retry      => $retry,
                expire     => $expire,
                minttl     => $minttl,
            }
        );
    }

    return $recs;
}

1;
