# Begin-Doc
# Name: NetMaint::Leases
# Type: module
# Description: object to manage access to dhcp lease information
# Comments: this module contains the ddns triggers that happen when leases are
# Comments: obtained or released.
# End-Doc

package NetMaint::Leases;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::UsageLogger;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::LastTouch;
require NetMaint::DBCache;

use Time::HiRes qw(time);

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Leases()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}      = new NetMaint::DB;
    $tmp->{util}    = new NetMaint::Util;
    $tmp->{dhcp}    = new NetMaint::DHCP;
    $tmp->{dns}     = new NetMaint::DNS;
    $tmp->{touch}   = new NetMaint::LastTouch;
    $tmp->{dbcache} = new NetMaint::DBCache;

    &LogAPIUsage();

    return bless $tmp, $class;
}

# Begin-Doc
# Name: GetCurLeases
# Type: method
# Description: Returns list of current leases for a given HW addr
# Syntax: @ips = $obj->GetCurLeases($ether);
# End-Doc
sub GetCurLeases {
    my $self    = shift;
    my $ether   = shift;
    my $util    = $self->{util};
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    $ether = $util->CondenseEther($ether);

    my ( $qry, $cid );

    my @ips = ();

    $qry = "select ip from dhcp_curleases where ether=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $ether )
        || $db->SQL_Error( $qry . " ($ether)" ) && return undef;

    while ( my ($ip) = $db->SQL_FetchRow($cid) ) {
        push( @ips, $ip );
    }

    return @ips;
}

# Begin-Doc
# Name: GetCurLeaseByIP
# Type: method
# Description: Returns current HW addr for a given IP
# Syntax: $ether = $obj->GetCurLeaseByIP($ip);
# End-Doc
sub GetCurLeaseByIP {
    my $self    = shift;
    my $ip      = shift;
    my $util    = $self->{util};
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    $ip = $util->CondenseIP($ip);

    my ( $qry, $cid );

    my $ether;

    $qry = "select ether from dhcp_curleases where ip=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $ip )
        || $db->SQL_Error( $qry . " ($ip)" ) && return undef;
    my ($ether) = $db->SQL_FetchRow($cid);

    return $ether;
}

# Begin-Doc
# Name: RecordNewLease
# Type: method
# Description: Updates records that a lease was granted
# Syntax: $obj->RecordNewLease(%details);
# End-Doc
sub RecordNewLease {
    my $self    = shift;
    my %opts    = @_;
    my $util    = $self->{util};
    my $ts      = $opts{tstamp} || time;
    my $ether   = $util->CondenseEther( $opts{ether} );
    my $ip      = $util->CondenseIP( $opts{ip} );
    my $gw      = $util->CondenseIP( $opts{gateway} );
    my $server  = lc $opts{server};
    my $type    = uc $opts{type};
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};
    my $cid;
    my $qry;
    my $dns   = $self->{dns};
    my $dhcp  = $self->{dhcp};
    my $debug = 0;
    my $st;

    $debug && print "recording new lease for ether $ether at ip $ip\n";
    $self->{touch}->UpdateLastTouch( ether => $ether, ip => $ip );

    # insert into queue - ignore errors
    $qry = "insert into dhcp_acklog_queue (type,ether,ip,tstamp,server,gateway) values (?,?,?,from_unixtime(?),?,?)";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $type, $ether, $ip, $ts, $server, $gw );

    $qry = "update dhcp_lastack set type=?, ip=?, tstamp=from_unixtime(?), server=? where ether=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $type, $ip, $ts, $server, $ether )
        || $db->SQL_Error($qry);

    if ( $db->SQL_RowCount() == 0 ) {

        # We know we're going to likely get an error on this, so ignore it.
        $qry = "insert into dhcp_lastack (type,ether,ip,tstamp,server) values (?,?,?,from_unixtime(?),?)";
        $cid = $dbcache->open($qry);

        # ignore errors
        $db->SQL_ExecQuery( $cid, $type, $ether, $ip, $ts, $server );
    }

    # Clear any old dynamic registrations
    my @oldips = $self->GetCurLeases($ether);

    #my $dynhostname = "dyn-ether-" . lc($ether) . ".device.spirenteng.com";

    my $daship = $ip;
    $daship =~ s/\./-/go;
    my $dynhostname = "dhcp-${daship}.spirenteng.com";

    $debug && print "old ips = ", join( ", ", @oldips ), "\n";
    $dns->BlockUpdates();

    $dns->Delete_Dynamic_ByHostFwdOnly($dynhostname);
    foreach my $oldip (@oldips) {
        $dns->Delete_Dynamic_ByIP($oldip);
    }

    # Look up hostname from this ethernet addr
    my $hostname = $dhcp->SearchByEtherExact($ether);
    if ($hostname) {
        $dns->Delete_Dynamic_ByHostFwdOnly( "tmp-" . $hostname );
        $dns->Delete_Dynamic_ByHostFwdOnly($hostname);
    }

    $debug && print "got hostname = $hostname\n";

    # If this is an unknown host, we should still give it a usable name
    # so that the mail relay is happy.
    my $cnt = 0;
    if ( !$hostname ) {
        $hostname = $dynhostname;
    }
    else {
        $cnt = $dns->Count_Static_A_Records($hostname);
        $debug && print "static count = $cnt\n";
    }

    #
    # This is creating a record for 'dyn-$host' even when it doesn't need to
    # Should fetch the A records, see if only one, and only if different put
    # the lease in.
    #

    if ( $cnt > 0 ) {
        my $tmphost = "dyn-$hostname";
        $debug && print "using host = $tmphost\n";
        $dns->Add_Dynamic_HostIP( $tmphost, $ip );
    }
    else {
        $dns->Add_Dynamic_HostIP( $hostname, $ip );
    }

    # Release dns and trigger queued updates
    $dns->UnblockUpdates();

    # Now update the curleases table, this potentially allows more than one lease to
    # accumulate, but we'll just use the most recent one when registering ip
    $qry = "delete from dhcp_curleases where ip=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $ip ) || $db->SQL_Error($qry);

    $qry = "replace into dhcp_curleases(ether,ip,tstamp) values (?,?,now())";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, $ether, $ip ) || $db->SQL_Error($qry);

}

# Begin-Doc
# Name: RecordReleasedLease
# Type: method
# Description: Updates records that a lease was granted
# Syntax: $obj->RecordReleasedLease(%details);
# End-Doc
sub RecordReleasedLease {
    my $self    = shift;
    my %opts    = @_;
    my $util    = $self->{util};
    my $ts      = $opts{tstamp} || time;
    my $ether   = $util->CondenseEther( $opts{ether} );
    my $ip      = $util->CondenseIP( $opts{ip} );
    my $gw      = $util->CondenseIP( $opts{gateway} );
    my $db      = $self->{db};
    my $dbcache = $self->{dbcache};

    my $dns = $self->{dns};

    my $qry;
    my $cid;

    $qry = "delete from dhcp_curleases where ether=? and ip=?";
    $cid = $dbcache->open($qry);

    $db->SQL_ExecQuery( $cid, $ether, $ip ) || $db->SQL_Error($qry);

    $self->{touch}->UpdateLastTouch( ether => $ether, ip => $ip );

    $dns->Delete_Dynamic_ByIP($ip);
}

# Begin-Doc
# Name: RecordIgnoredLease
# Type: method
# Description: Updates records that a lease was ignored
# Syntax: $obj->RecordIgnoredLease(%details);
# End-Doc
sub RecordIgnoredLease {
    my $self  = shift;
    my %opts  = @_;
    my $util  = $self->{util};
    my $ts    = $opts{tstamp} || time;
    my $ether = $util->CondenseEther( $opts{ether} );
    my $gw    = $util->CondenseIP( $opts{gateway} );
    my $db    = $self->{db};
    my $cid;
    my $dbcache = $self->{dbcache};
    my $server  = lc $opts{server};

    $self->{touch}->UpdateLastTouch( ether => $ether );

    # insert into queue - ignore errors
    my $qry
        = "insert into dhcp_acklog_queue (type,ether,ip,tstamp,server,gateway) values (?,?,'',from_unixtime(?),?,?)";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, "IGNORE", $ether, $ts, $server, $gw );

    # We know we're going to likely get an error on this, so ignore it.
    $qry = "insert into dhcp_lastack (type,ether,ip,tstamp,server) values (?,?,'',from_unixtime(?),?)";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, "IGNORE", $ether, $ts, $server );

    $qry = "update dhcp_lastack set type=?, ip='', tstamp=from_unixtime(?), server=? where ether=?";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, "IGNORE", $ts, $server, $ether )
        || $db->SQL_Error($qry);
}

# Begin-Doc
# Name: RecordErrorLease
# Type: method
# Description: Updates records that a lease was ignored
# Syntax: $obj->RecordErrorLease(%details);
# End-Doc
sub RecordErrorLease {
    my $self  = shift;
    my %opts  = @_;
    my $util  = $self->{util};
    my $ts    = $opts{tstamp} || time;
    my $ether = $util->CondenseEther( $opts{ether} );
    my $gw    = $util->CondenseIP( $opts{gateway} );
    my $ip    = $util->CondenseIP( $opts{ip} );
    my $db    = $self->{db};
    my $cid;
    my $dbcache = $self->{dbcache};
    my $server  = lc $opts{server};

    # insert into queue - ignore errors
    my $qry = "insert into dhcp_acklog_queue (type,ether,ip,tstamp,server,gateway) values (?,?,?,from_unixtime(?),?,?)";
    $cid = $dbcache->open($qry);
    $db->SQL_ExecQuery( $cid, "ERROR", $ether, $ip, $ts, $server, $gw );
}

1;
