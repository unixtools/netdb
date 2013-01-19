# Begin-Doc
# Name: NetMaint::Hosts
# Type: module
# Description: object to manage access to host information
# End-Doc

package NetMaint::Hosts;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::UsageLogger;
require NetMaint::DB;
require NetMaint::Logging;
require NetMaint::LastTouch;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Hosts()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}    = new NetMaint::DB;
    $tmp->{log}   = new NetMaint::Logging;
    $tmp->{touch} = new NetMaint::LastTouch;

    &LogAPIUsage();

    return bless $tmp, $class;
}

# Begin-Doc
# Name: GetHostInfo
# Type: method
# Description: Returns host info for a particular host
# Comments: returns undef if not found
# Syntax: $info = $obj->GetHostInfo($host);
# End-Doc
sub GetHostInfo {
    my $self = shift;
    my $host = lc shift;

    my $db = $self->{db};
    my ( $qry, $cid );
    my $info = {};

    $qry
        = "select host,domain,type,owner,ctime,"
        . "mtime,modifiedby,description,location,adminlock,admin_comments, "
        . "purge_date, purge_date_updated "
        . "from hosts where host=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return undef;
    my ($thost, $domain,   $type,      $owner,          $ctime, $mtime, $modby,
        $desc,  $location, $adminlock, $admin_comments, $pd,    $pdu
    ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    if ( $thost ne $host ) {
        return undef;
    }

    if ( $pd =~ /1969/ || $pdu =~ /1969/ ) {
        $pd  = "";
        $pdu = "";
    }

    $info->{host}               = $host;
    $info->{domain}             = $domain;
    $info->{type}               = $type;
    $info->{owner}              = $owner;
    $info->{modifiedby}         = $modby;
    $info->{description}        = $desc;
    $info->{ctime}              = $ctime;
    $info->{mtime}              = $mtime;
    $info->{location}           = $location;
    $info->{adminlock}          = $adminlock;
    $info->{admin_comments}     = $admin_comments;
    $info->{purge_date}         = $pd;
    $info->{purge_date_updated} = $pdu;

    return $info;
}

# Begin-Doc
# Name: SearchByName
# Type: method
# Description: Returns array of hostnames matching substring
# Comments: returns undef if not found
# Syntax: @hosts = $obj->SearchByName($substring, [$max]);
# End-Doc
sub SearchByName {
    my $self = shift;
    my $pat  = lc shift;
    my $max  = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @hosts;
    my @vals;

    $qry = "select host from hosts where host like ?";
    push( @vals, "%" . $pat . "%" );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals )
        || $db->SQL_Error($qry) && return undef;
    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return @hosts;
}

# Begin-Doc
# Name: SearchByLocation
# Type: method
# Description: Returns array of hosts with location matching substring
# Comments: returns undef if not found
# Syntax: @hosts = $obj->SearchByLocation($substring, [$max]);
# End-Doc
sub SearchByLocation {
    my $self = shift;
    my $pat  = lc shift;
    my $max  = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @hosts;
    my @vals;

    $qry = "select host from hosts where lower(location) like ?";
    push( @vals, "%" . $pat . "%" );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals )
        || $db->SQL_Error($qry) && return undef;
    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return @hosts;
}

# Begin-Doc
# Name: SearchByDescription
# Type: method
# Description: Returns array of hosts with description matching substring
# Comments: returns undef if not found
# Syntax: @hosts = $obj->SearchByDescription($substring, [$max]);
# End-Doc
sub SearchByDescription {
    my $self = shift;
    my $pat  = lc shift;
    my $max  = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @hosts;
    my @vals;

    $qry = "select host from hosts where lower(description) like ?";
    push( @vals, "%" . $pat . "%" );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals )
        || $db->SQL_Error($qry) && return undef;
    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return @hosts;
}

# Begin-Doc
# Name: SearchByOwnerExact
# Type: method
# Description: Returns array of hostnames with owner matching $owner
# Comments: returns empty array if not found
# Syntax: @hosts = $obj->SearchByOwnerExact($owner, [$max]);
# End-Doc
sub SearchByOwnerExact {
    my $self  = shift;
    my $owner = lc shift;
    my $max   = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @hosts;
    my @vals;

    $qry = "select host from hosts where owner=?";
    push( @vals, $owner );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals )
        || $db->SQL_Error($qry) && return undef;
    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return @hosts;
}

# Begin-Doc
# Name: GetDefaultOwner
# Type: method
# Description: Returns default owner based on registration type
# Comments: returns remote user or some other userid
# Syntax: my $defowner = $obj->GetDefaultOwner([type => $type], [nametype => $nametype]);
# End-Doc
sub GetDefaultOwner {
    my $self     = shift;
    my %opts     = @_;
    my $defowner = $ENV{REMOTE_USER};
    my $nametype = $opts{nametype};
    my $type     = $opts{type};

    if ( $type eq "server" || $type eq "cname" || $type eq "network" ) {
        $defowner = "netdb";
    }

    return $defowner;
}

# Begin-Doc
# Name: CheckNameLength
# Type: method
# Description: Check length restrictions of hostname, returns error message if invalid, undef if ok
# Syntax: my $err = $obj->CheckNameLength(host => $host)
# End-Doc
sub CheckNameLength {
    my $self = shift;
    my %opts = @_;
    my $host = $opts{host};

    if ( $host =~ /\.managed\.mst\.edu$/o ) {
        my $shost = $host;
        $shost =~ s/\..*//go;
        if ( length($shost) > 15 ) {
            return
                "Total length of short hostname ($shost) in managed.mst.edu domain exceeds maximum of 15 characters.";
        }
    }

    if ( length($host) > 60 ) {
        return "Total length of long hostname ($host) exceeds maximum of 60 characters.";
    }

    return undef;
}

# Begin-Doc
# Name: CheckValidNameType
# Type: method
# Description: Returns true if a name type combination is valid
# Comments: hardwired here to avoid duplication, does NOT check authorization, only validity
# Syntax: my $valid = $obj->CheckValidNameType(type => $type, nametype => $nametype);
# End-Doc
sub CheckValidNameType {
    my $self     = shift;
    my %opts     = @_;
    my $type     = $opts{type};
    my $nametype = $opts{nametype};

    if ( $type eq "server" || $type eq "cname" ) {
        return $nametype eq "customname";
    }
    elsif ( $type eq "guest" ) {
        return $nametype eq "ownername";
    }

    # Fall through and allow it
    return 1;
}

# Begin-Doc
# Name: CheckValidNameTypeDomain
# Type: method
# Description: Returns true if a name type, type, domain combination is valid
# Comments: hardwired here to avoid duplication, does NOT check authorization, only validity
# Syntax: my $valid = $obj->CheckValidNameTypeDomain(type => $type, nametype => $nametype, domain => $domain);
# End-Doc
sub CheckValidNameTypeDomain {
    my $self     = shift;
    my %opts     = @_;
    my $type     = $opts{type};
    my $nametype = $opts{nametype};
    my $domain   = $opts{domain};

    if ( $domain eq "prn.mst.edu" && $type ne "printer" ) {
        return 0;
    }

    if ( $type eq "guest" && ( $nametype ne "ownername" || $domain !~ /guest/ ) ) {
        return 0;
    }

    if ( $type ne "guest" && $domain =~ /guest/ ) {
        return 0;
    }

    return 1;
}

# Begin-Doc
# Name: GetFreeIndexes
# Type: method
# Description: Returns array of indexes for a given host name type and owner
# Comments: returns empty array if none available, sorted zero-prefixed two-digit indexes otherwise
# Syntax: @indexes = $obj->GetFreeIndexes(owner => $owner, [nametype => $type]);
# End-Doc
sub GetFreeIndexes {
    my $self     = shift;
    my %opts     = @_;
    my $owner    = lc $opts{owner};
    my $nametype = $opts{nametype};

    my $pat;
    if ( $nametype eq "ownername" ) {
        $pat = qr/^s(\d\d)/;
    }
    else {

        # this should not occur
        return ();
    }

    my %used = ();

    my @hosts = $self->SearchByOwnerExact($owner);
    foreach my $host (@hosts) {
        if ( $host =~ /$pat/ ) {
            $used{ int($1) } = 1;
        }
    }

    my @indexes = ();
    for ( my $i = 1; $i <= 99; $i++ ) {
        if ( !$used{$i} ) {
            push( @indexes, sprintf( "%.2d", $i ) );
        }
    }

    return @indexes;
}

# Begin-Doc
# Name: SearchByOwner
# Type: method
# Description: Returns array of hostnames with owner matching substring
# Comments: returns empty hash if not found, otherwise hash keyed on hostname, value is owner
# Syntax: %hosts = $obj->SearchByOwner($substring, [$max]);
# End-Doc
sub SearchByOwner {
    my $self = shift;
    my $pat  = lc shift;
    my $max  = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my %hosts;
    my @vals;

    $qry = "select host,owner from hosts where owner like ?";
    push( @vals, "%" . $pat . "%" );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals )
        || $db->SQL_Error($qry) && return undef;
    while ( my ( $host, $owner ) = $db->SQL_FetchRow($cid) ) {
        $hosts{$host} = $owner;
    }
    $db->SQL_CloseQuery($cid);

    return %hosts;
}

# Begin-Doc
# Name: SearchByDomainExact
# Type: method
# Description: Returns array of hostnames with domain matching $domain
# Comments: returns undef if not found
# Syntax: @hosts = $obj->SearchByDomainExact($domain, [$max]);
# End-Doc
sub SearchByDomainExact {
    my $self = shift;
    my $dom  = lc shift;
    my $max  = shift || 0;

    my $db = $self->{db};
    my ( $qry, $cid );
    my @hosts;
    my @vals;

    $qry = "select host from hosts where domain=?";
    push( @vals, $dom );
    if ( $max > 0 ) {
        $qry .= " limit ?";
        push( @vals, $max );
    }
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, @vals )
        || $db->SQL_Error($qry) && return undef;
    while ( my ($host) = $db->SQL_FetchRow($cid) ) {
        push( @hosts, $host );
    }
    $db->SQL_CloseQuery($cid);

    return @hosts;
}

# Begin-Doc
# Name: DeleteHost
# Type: method
# Description: Deletes all host data associated with a host
# Syntax: $obj->DeleteHost($host);
# End-Doc
sub DeleteHost {
    my $self = shift;
    my $host = lc shift;
    my $log  = $self->{log};
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "delete from metadata where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $qry = "delete from hosts where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $log->Log( action => "deleted host", host => $host );
}

# Begin-Doc
# Name: SetAdminLock
# Type: method
# Description: Sets administrative lock for a host
# Syntax: $obj->SetAdminLock($host);
# End-Doc
sub SetAdminLock {
    my $self = shift;
    my $host = lc shift;
    my $log  = $self->{log};

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "update hosts set adminlock=1 where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $self->MarkUpdated($host);

    $log->Log( action => "set administrative lock", host => $host );
}

# Begin-Doc
# Name: ClearAdminLock
# Type: method
# Description: Clears administrative lock for a host
# Syntax: $obj->ClearAdminLock($host);
# End-Doc
sub ClearAdminLock {
    my $self = shift;
    my $host = lc shift;
    my $log  = $self->{log};
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "update hosts set adminlock=0 where host=?";
    $db->SQL_ExecQuery( $qry, $host ) || $db->SQL_Error($qry);

    $self->MarkUpdated($host);

    $log->Log( action => "cleared administrative lock", host => $host );
}

# Begin-Doc
# Name: SetLocation
# Type: method
# Description: Updates location information for a host
# Syntax: $obj->SetLocation($host, $location);
# End-Doc
sub SetLocation {
    my $self = shift;
    my $host = lc shift;
    my $loc  = shift;
    my $log  = $self->{log};

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "update hosts set location=? where host=?";
    $db->SQL_ExecQuery( $qry, $loc, $host ) || $db->SQL_Error($qry);

    $self->{touch}->UpdateLastTouch( host => $host );

    $self->MarkUpdated($host);

    $log->Log( action => "set location", location => $loc );
}

# Begin-Doc
# Name: SetOwner
# Type: method
# Description: Updates owner information for a host
# Syntax: $obj->SetOwner($host, $owner);
# End-Doc
sub SetOwner {
    my $self  = shift;
    my $host  = lc shift;
    my $owner = shift;
    my $log   = $self->{log};

    my $db = $self->{db};

    my ( $qry, $cid );

    $qry = "update hosts set owner=? where host=?";
    $db->SQL_ExecQuery( $qry, $owner, $host ) || $db->SQL_Error($qry);

    $self->{touch}->UpdateLastTouch( host => $host );

    $self->MarkUpdated($host);

    $log->Log( action => "set owner", owner => $owner );
}

# Begin-Doc
# Name: SetDescription
# Type: method
# Description: Updates description information for a host
# Syntax: $obj->SetDescription($host, $location);
# End-Doc
sub SetDescription {
    my $self = shift;
    my $host = lc shift;
    my $desc = shift;
    my $log  = $self->{log};
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "update hosts set description=? where host=?";
    $db->SQL_ExecQuery( $qry, $desc, $host ) || $db->SQL_Error($qry);

    $self->{touch}->UpdateLastTouch( host => $host );

    $self->MarkUpdated($host);

    $log->Log( action => "set description", description => $desc );
}

# Begin-Doc
# Name: SetAdminComments
# Type: method
# Description: Updates admin comments information for a host
# Syntax: $obj->SetAdminComments($host, $location);
# End-Doc
sub SetAdminComments {
    my $self = shift;
    my $host = lc shift;
    my $desc = shift;
    my $log  = $self->{log};
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "update hosts set admin_comments=? where host=?";
    $db->SQL_ExecQuery( $qry, $desc, $host ) || $db->SQL_Error($qry);

    $self->{touch}->UpdateLastTouch( host => $host );

    $self->MarkUpdated($host);

    $log->Log( action => "set admin comments", admin_comments => $desc );
}

# Begin-Doc
# Name: GetAllAdminComments
# Type: method
# Description: Returns ref to hash of host admin comments
# Syntax: $hostcomments = $obj->GetAllAdminComments();
# End-Doc
sub GetAllAdminComments {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $res = {};

    $qry = "select host,admin_comments from hosts where admin_comments is not null";
    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        return undef;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $host, $comments ) = @$rref;
        $res->{$host} = $comments;
    }

    return $res;
}

# Begin-Doc
# Name: GetAllHostOwners
# Type: method
# Description: Returns ref to hash of host owners
# Syntax: $hostowners = $obj->GetAllHostOwners();
# End-Doc
sub GetAllHostOwners {
    my $self = shift;
    my $host = shift;

    my $db = $self->{db};

    my ( $qry, $cid );
    my $res = {};

    $qry = "select host,owner from hosts";
    unless ( $cid = $db->SQL_OpenQuery($qry) ) {
        return undef;
    }
    my $allrows = $db->SQL_FetchAllRows($cid);
    $db->SQL_CloseQuery($cid);

    foreach my $rref (@$allrows) {
        my ( $host, $owner ) = @$rref;
        $res->{$host} = $owner;
    }

    return $res;
}

# Begin-Doc
# Name: MarkUpdated
# Type: method
# Description: Updates modification information for a host
# Syntax: $obj->MarkUpdated($host);
# End-Doc
sub MarkUpdated {
    my $self = shift;
    my $host = lc shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    return if ( !$host );

    $self->{touch}->UpdateLastTouch( host => $host );

    $qry = "update hosts set mtime=now(),modifiedby=? where host=?";
    $db->SQL_ExecQuery( $qry, $ENV{REMOTE_USER}, $host )
        || $db->SQL_Error($qry);
}

# Begin-Doc
# Name: CreateHost
# Type: method
# Description: Creates a new host entry
# Syntax: $obj->CreateHost(%info);
# Comments: %info has keys host, domain, owner, type
# End-Doc
sub CreateHost {
    my $self   = shift;
    my %info   = @_;
    my $host   = lc $info{host} || return "must specify host";
    my $domain = lc $info{domain} || return "must specify domain";
    my $type   = lc $info{type} || return "must specify type";
    my $owner  = lc $info{owner} || return "must specify owner";
    my $log    = $self->{log};
    my $db     = $self->{db};

    my ( $qry, $cid );

    $log->Log(
        action => "attempting to create host",
        host   => $host,
        domain => $domain,
        type   => $type,
        owner  => $owner
    );

    $self->{touch}->UpdateLastTouch( host => $host );

    $qry = "insert into hosts(host,domain,type,owner,ctime,mtime,modifiedby) values (?,?,?,?,now(),now(),?)";
    $db->SQL_ExecQuery( $qry, $host, $domain, $type, $owner, $ENV{REMOTE_USER} )
        || $db->SQL_Error($qry) && return "failed to register host";

    $log->Log(
        action => "created host",
        host   => $host,
        domain => $domain,
        type   => $type,
        owner  => $owner
    );

    return undef;
}

# Begin-Doc
# Name: SendAdminDisableNotice
# Syntax: $hosts->SendAdminDisableNotice($host)
# Description: sends email notification when a host is administratively disabled
# End-Doc
sub SendAdminDisableNotice {
    my $self = shift;
    my $host = shift;

    my $info = $self->GetHostInfo($host);

    open( my $sfh, "|/usr/lib/sendmail -t -fsecurity" );
    print $sfh "From: security\@spirenteng.com\n";
    print $sfh "Subject: System Administratively Disabled\n";
    print $sfh "To: ", $info->{owner}, "\n";
    print $sfh "\n";
    print $sfh "System Name: $host\n";
    print $sfh "\n";
    print $sfh "Situation: ", $info->{admin_comments}, "\n";
    print $sfh "\n";
    print $sfh "
Once the issue has been resolved contact EngOps to have network access
restored.";
    print $sfh "\n";
    close($sfh);
}

1;
