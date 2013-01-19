# Begin-Doc
# Name: NetMaint::LastTouch
# Type: module
# Description: object to manage access to host/ip/ether last seen/touched information
# End-Doc

package NetMaint::LastTouch;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use UMR::UsageLogger;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::DBCache;

@ISA    = qw(Exporter);
@EXPORT = qw();

#
# Keep caches so we can avoid doing db updates when not needed
#
my %cache_lt_ip    = ();
my %cache_lt_ether = ();
my %cache_lt_host  = ();

# Was 12 days, but let's just set to 4...
my $cache_interval = 4 * 24 * 60 * 60;

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::LastTouch()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}      = new NetMaint::DB;
    $tmp->{util}    = new NetMaint::Util;
    $tmp->{dbcache} = new NetMaint::DBCache;

    &LogAPIUsage();

    return bless $tmp, $class;
}

# Begin-Doc
# Name: PreLoadCache
# Type: method
# Description: Pre loads the last touch cache for the given type
# Syntax: $obj->PreLoadCache($type);
# Comments: $type is one of host, ether, or ip
# End-Doc
sub PreLoadCache {
    my $self = shift;
    my $type = shift;

    my $db = $self->{db};

    my $ts   = time;
    my $mult = 24 * 60 * 60;

    if ( $type eq "ip" ) {
        my $qry
            = "select ip,unix_timestamp(now())-unix_timestamp(tstamp) from last_touch_ip where unix_timestamp(now())-unix_timestamp(tstamp)<?";
        my $cid = $db->SQL_OpenQuery( $qry, $cache_interval ) || $db->SQL_Error($qry) && return undef;
        while ( my ( $ip, $age ) = $db->SQL_FetchRow($cid) ) {
            $cache_lt_ip{$ip} = $ts - $age;
        }
        $db->SQL_CloseQuery($cid);
    }
    elsif ( $type eq "ether" ) {
        my $qry
            = "select ether,unix_timestamp(now())-unix_timestamp(tstamp) from last_touch_ether where unix_timestamp(now())-unix_timestamp(tstamp)<?";
        my $cid = $db->SQL_OpenQuery( $qry, $cache_interval ) || $db->SQL_Error($qry) && return undef;
        while ( my ( $ether, $age ) = $db->SQL_FetchRow($cid) ) {
            $cache_lt_ether{$ether} = $ts - $age;
        }
        $db->SQL_CloseQuery($cid);
    }
    elsif ( $type eq "host" ) {
        my $qry
            = "select host,unix_timestamp(now())-unix_timestamp(tstamp) from last_touch_host where unix_timestamp(now())-unix_timestamp(tstamp)<?";
        my $cid = $db->SQL_OpenQuery( $qry, $cache_interval ) || $db->SQL_Error($qry) && return undef;
        while ( my ( $host, $age ) = $db->SQL_FetchRow($cid) ) {
            $cache_lt_host{$host} = $ts - $age;
        }
        $db->SQL_CloseQuery($cid);
    }
}

# Begin-Doc
# Name: UpdateLastTouch
# Type: method
# Description: Updates the last touch time for ether, ip, or host
# Syntax: $obj->UpdateLastTouch(%options);
# Comments: %options has keys host, ether, ip, any combination can be specified
# End-Doc
sub UpdateLastTouch {
    my $self    = shift;
    my %opts    = @_;
    my $ether   = $opts{ether};
    my $ip      = $opts{ip};
    my $host    = $opts{host};
    my $dbcache = $self->{dbcache};

    my $util = $self->{util};
    my $db   = $self->{db};

    my ( $qry, $cid );
    my $info = [];

    my $tm = time;

    if ( $ether && ( ( $tm - $cache_lt_ether{$ether} ) > $cache_interval ) ) {
        $qry = "update last_touch_ether set tstamp=now() where ether=?";
        $cid = $dbcache->open($qry);
        $db->SQL_ExecQuery( $cid, $util->CondenseEther($ether) )
            || $db->SQL_Error( $qry . " ($ether)" );

        if ( $db->SQL_RowCount() == 0 ) {
            $qry = "insert into last_touch_ether(ether,tstamp) values (?,now())";
            $cid = $dbcache->open($qry);
            $db->SQL_ExecQuery( $cid, $util->CondenseEther($ether) );
        }

        $cache_lt_ether{$ether} = $tm;
    }

    if ( $ip && ( ( $tm - $cache_lt_ip{$ip} ) > $cache_interval ) ) {
        $qry = "update last_touch_ip set tstamp=now() where ip=?";
        $cid = $dbcache->open($qry);
        $db->SQL_ExecQuery( $cid, $util->CondenseIP($ip) )
            || $db->SQL_Error( $qry . " ($ip)" );

        if ( $db->SQL_RowCount() == 0 ) {
            $qry = "insert into last_touch_ip(ip,tstamp) values (?,now())";
            $cid = $dbcache->open($qry);
            $db->SQL_ExecQuery( $cid, $util->CondenseIP($ip) );
        }

        $cache_lt_ip{$ip} = $tm;
    }

    if ( $host && ( ( $tm - $cache_lt_host{$host} ) > $cache_interval ) ) {
        $qry = "update last_touch_host set tstamp=now() where host=?";
        $cid = $dbcache->open($qry);
        $db->SQL_ExecQuery( $cid, lc $host )
            || $db->SQL_Error( $qry . " ($host)" );

        if ( $db->SQL_RowCount() == 0 ) {
            $qry = "insert into last_touch_host(host,tstamp) values (?,now())";
            $cid = $dbcache->open($qry);
            $db->SQL_ExecQuery( $cid, lc $host );
        }

        $cache_lt_host{$host} = $tm;
    }
}

1;
