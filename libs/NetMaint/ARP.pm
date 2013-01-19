# Begin-Doc
# Name: NetMaint::ARP
# Type: module
# Description: object to manage access to arp scan information
# End-Doc

package NetMaint::ARP;
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
# Syntax: $maint = new NetMaint::ARP()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}      = new NetMaint::DB;
    $tmp->{util}    = new NetMaint::Util;
    $tmp->{dbcache} = new NetMaint::DBCache;


    return bless $tmp, $class;
}

# Begin-Doc
# Name: GetIPLastARP
# Type: method
# Description: Returns hash containing last arp history record for a given IP
# Syntax: %info = $obj->GetIPLastARP($ip);
# Comments: returns empty array
# End-Doc
sub GetIPLastARP {
    my $self = shift;
    my $ip   = shift;

    my $util = $self->{util};
    my $db   = $self->{db};

    my ( $qry, $cid );
    my $info = [];

    $ip = $util->CondenseIP($ip);

    $qry
        = "select tstamp,unix_timestamp(now())-unix_timestamp(tstamp),ip,ether,router from arpscan where ip=? order by tstamp desc";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $ip ) || $db->SQL_Error($qry) && return undef;
    my ( $qtstamp, $qage, $qip, $qeth, $qrouter ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    if ( $qip eq $ip ) {
        return (
            ether  => $qeth,
            ip     => $qip,
            tstamp => $qtstamp,
            router => $qrouter,
            age    => $qage,
        );
    }
    else {
        return ();
    }
}

# Begin-Doc
# Name: GetEtherLastARP
# Type: method
# Description: Returns hash containing last arp history record for a given ether
# Syntax: %info = $obj->GetEtherLastARP($ether);
# Comments: returns empty array
# End-Doc
sub GetEtherLastARP {
    my $self  = shift;
    my $ether = shift;

    my $util = $self->{util};
    my $db   = $self->{db};

    my ( $qry, $cid );
    my $info = [];

    $ether = $util->CondenseEther($ether);

    $qry
        = "select tstamp,unix_timestamp(now())-unix_timestamp(tstamp),ip,ether,router from arpscan where ether=? order by tstamp desc";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $ether )
        || $db->SQL_Error($qry) && return undef;
    my ( $qtstamp, $qage, $qip, $qeth, $qrouter ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    if ( $qeth eq $ether ) {
        return (
            ether  => $qeth,
            ip     => $qip,
            tstamp => $qtstamp,
            router => $qrouter,
            age    => $qage,
        );
    }
    else {
        return ();
    }
}

# Begin-Doc
# Name: GetARPHistory
# Type: method
# Description: Returns array ref of arp history records matching a particular ethernet addr or ip
# Syntax: $recs = $obj->GetARPHistory(%filter);
# Comments: %filter has keys "ether" and/or "ip" and/or "router", at least one of 'ether' or 'ip' must be specified
# Comments: returns undef if not found
# End-Doc
sub GetARPHistory {
    my $self   = shift;
    my %filter = @_;
    my $ether  = $filter{ether};
    my $ip     = $filter{ip};
    my $router = $filter{router};

    my $util = $self->{util};
    my $db   = $self->{db};

    my ( $qry, $cid );
    my $info = [];

    if ( !$ether && !$ip ) {
        return undef;
    }

    my @where  = ();
    my @values = ();
    if ($ether) {
        push( @where,  "ether=?" );
        push( @values, $util->CondenseEther($ether) );
    }
    if ($ip) {
        push( @where,  "ip=?" );
        push( @values, $util->CondenseIP($ip) );
    }
    if ($router) {
        push( @where,  "router=?" );
        push( @values, $util->CondenseIP($router) );
    }

    my $cache = $self->{dbcache};
    $qry = "select ether, ip, tstamp, router from arpscan where " . join( " and ", @where ) . " order by tstamp";

    $cid = $cache->open($qry);
    $db->SQL_ExecQuery( $cid, @values )
        || $db->SQL_Error($qry) && return undef;

    while ( my ( $qeth, $qip, $qtstamp, $qrouter ) = $db->SQL_FetchRow($cid) ) {
        push(
            @$info,
            {   ether  => $qeth,
                ip     => $qip,
                tstamp => $qtstamp,
                router => $qrouter,
            }
        );
    }

    return $info;
}

1;
