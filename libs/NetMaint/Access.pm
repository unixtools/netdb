# Begin-Doc
# Name: NetMaint::Access
# Type: module
# Description: object to manage access privileges for netdb tools
# End-Doc

package NetMaint::Access;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::ADSObject;
use Local::PrivSys;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Logging;
require NetMaint::DBCache;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Access()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}    = new NetMaint::DB;
    $tmp->{util}  = new NetMaint::Util;
    $tmp->{log}   = new NetMaint::Logging;
    $tmp->{cache} = new NetMaint::DBCache;

    $tmp->{access_data}        = [];
    $tmp->{access_data_loaded} = {};


    return bless $tmp, $class;
}

# Begin-Doc
# Name: CleanOldData
# Type: function
# Description: Removes all marked expanded rule data
# Syntax: $obj->CleanOldData()
# End-Doc
sub CleanOldData {
    my $self = shift;
    my $db   = $self->{db};
    my ( $qry, $cid );

    $qry = "delete from access_data where id not in (select id from access_rules)";
    $cid = $db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && return undef;
}

# Begin-Doc
# Name: GetAllRules
# Type: function
# Description: Retrieves all rules from access_rules
# Syntax: $obj->GetAllRules()
# End-Doc
sub GetAllRules {
    my $self  = shift;
    my $db    = $self->{db};
    my $rules = {};
    my ( $qry, $cid );

    $qry = "select id,who,types,domains,subnets,flags,actions from access_rules";
    $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && return undef;
    while ( my ( $id, $who, $types, $domains, $subnets, $flags, $actions ) = $db->SQL_FetchRow($cid) ) {
        $who     =~ s/\s+//gio;
        $types   =~ s/\s+//gio;
        $domains =~ s/\s+//gio;
        $subnets =~ s/\s+//gio;
        $flags   =~ s/\s+//gio;
        $actions =~ s/\s+//gio;

        $rules->{$id} = {
            id      => $id,
            who     => $who,
            types   => $types,
            domains => $domains,
            subnets => $subnets,
            flags   => $flags,
            actions => $actions,
        };
    }
    $db->SQL_CloseQuery($cid);

    return $rules;
}

# Begin-Doc
# Name: DeleteRule
# Type: function
# Description: Deletes a rule from access_rules
# Syntax: $obj->DeleteRule($rule_id)
# End-Doc
sub DeleteRule {
    my $self = shift;
    my $id   = int(shift);
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "delete from access_rules where id=" . int($id);
    $db->SQL_ExecQuery($qry) || $db->SQL_Error($qry);

    $qry = "delete from access_data where id=" . int($id);
    $db->SQL_ExecQuery($qry) || $db->SQL_Error($qry);
}

# Begin-Doc
# Name: AddRule
# Type: function
# Description: Retrieves a rule from access_rules
# Syntax: $obj->AddRule(%info)
# Comments: %info has keys who, types, domains, subnets, flags, and actions
# Comments: values should be comma separated lists
# End-Doc
sub AddRule {
    my $self    = shift;
    my %info    = @_;
    my $who     = $info{who};
    my $types   = $info{types};
    my $domains = $info{domains};
    my $subnets = $info{subnets};
    my $flags   = $info{flags};
    my $actions = $info{actions};
    my $db      = $self->{db};

    my ( $qry, $cid );

    $qry = "insert into access_rules(who,types,domains,subnets,flags,actions) values (?,?,?,?,?,?)";
    $db->SQL_ExecQuery( $qry, $who, $types, $domains, $subnets, $flags, $actions )
        || $db->SQL_Error($qry);

    my $id = $db->SQL_SerialNumber();

    $self->ExpandRule($id);
}

# Begin-Doc
# Name: GetRule
# Type: function
# Description: Retrieves a rule from access_rules
# Syntax: $obj->GetRule($rule_id)
# End-Doc
sub GetRule {
    my $self = shift;
    my $id   = shift;
    my $db   = $self->{db};

    my ( $qry, $cid );

    $qry = "select id,who,types,domains,subnets,flags,actions from access_rules where id=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, int($id) )
        || $db->SQL_Error($qry) && return undef;
    my ( $qid, $who, $types, $domains, $subnets, $flags, $actions ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    if ( $qid == $id ) {
        $who     =~ s/\s+//gio;
        $types   =~ s/\s+//gio;
        $domains =~ s/\s+//gio;
        $subnets =~ s/\s+//gio;
        $flags   =~ s/\s+//gio;
        $actions =~ s/\s+//gio;

        return {
            id      => $id,
            who     => $who,
            types   => $types,
            domains => $domains,
            subnets => $subnets,
            flags   => $flags,
            actions => $actions,
        };
    }
    else {
        return undef;
    }
}

# Begin-Doc
# Name: LoadUserAccessData
# Type: function
# Description: Retrieves access rules for a particular userid
# Syntax: $obj->LoadUserAccessData($userid)
# End-Doc
sub LoadUserAccessData {
    my $self   = shift;
    my $db     = $self->{db};
    my $userid = shift;
    my ( $qry, $cid );
    my $ad = $self->{access_data};

    if ( $self->{access_data_loaded}->{$userid} ) {

        # already loaded
        return;
    }
    $self->{access_data_loaded}->{$userid} = 1;

    $qry = "select userid,type,domain,subnet,flag,action from access_data where userid=?";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $userid )
        || $db->SQL_Error($qry) && return undef;
    while ( my ( $userid, $type, $domain, $subnet, $flag, $action ) = $db->SQL_FetchRow($cid) ) {
        $userid =~ s/\s+//gio;
        $type   =~ s/\s+//gio;
        $domain =~ s/\s+//gio;
        $subnet =~ s/\s+//gio;
        $flag   =~ s/\s+//gio;
        $action =~ s/\s+//gio;

        push( @{$ad}, [ $userid, $type, $domain, $subnet, $flag, $action ] );
    }
    $db->SQL_CloseQuery($cid);

    return;
}

# Begin-Doc
# Name: GetHostNameType
# Type: function
# Description: Determines the name type of a host
# Syntax: $res = $obj->GetHostNameType($host)
# Comments: returns string 'ownername', 'customname'
# End-Doc
sub GetHostNameType {
    my $self = shift;
    my $host = lc shift;

    if (0) {

        # stub
    }

    elsif ( $host =~ /^s\d\d.*\.[a-z]+\.[a-z]+\.[a-z]+$/o ) {
        return "ownername";
    }
    elsif ( $host =~ /^s\d\d.*\.[a-z]+\.[a-z]+\.[a-z]+\.[a-z]+$/o ) {
        return "ownername";
    }

    elsif ($host !~ /^[0-9a-z]+[0-9a-z-]*[0-9a-z]+\.[0-9a-z]+\.spirenteng\.com$/o
        && $host !~ /^[0-9a-z]+[0-9a-z-]*[0-9a-z]+\.spirenteng\.com$/o &&
        $host !~ /^[0-9]+\.[0-9a-z]+\.spirenteng\.com/o )
    {
        return "invalidname";
    }
    else {
        return "customname";
    }
}

# Begin-Doc
# Name: CheckHostDeleteAccess
# Type: function
# Description: Checks if a particular userid is allowed to delete a host
# Syntax: $res = $obj->CheckHostDeleteAccess(userid => $userid, host => $host)
# Comments: $res is nonzero if delete access is approved
# End-Doc
sub CheckHostDeleteAccess {
    my $self   = shift;
    my %opts   = @_;
    my $userid = $opts{userid} || $ENV{REMOTE_USER} || return 0;
    my $host   = lc $opts{host} || return 0;

    my %privs = &PrivSys_FetchPrivs($userid);

    my $obo      = $privs{"netdb-admin"};
    my $nametype = $self->GetHostNameType($host);

    if ( $privs{"sysprog:netdb"} ) {
        return 1;
    }

    # Look up the type of this host
    my $db = $self->{db};
    my ( $qry, $cid );
    $qry = "select type,owner,adminlock from hosts where host=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && return 0;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return 0;
    my ( $hosttype, $hostowner, $hostadminlock ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);
    return 0 if ( !$hosttype );

    if ($hostadminlock) {
        if ( !$privs{"sysprog:netdb:adminlock"} ) {
            return 0;
        }
    }

    # Not sure about this...
    if ( $hostowner eq $userid ) {
        return 1;
    }

    if ( $hosttype eq "desktop"
        && ( $nametype eq "ownername" ) )
    {
        if ( $obo || ( $hostowner eq $userid ) ) {
            if ($self->CheckAllDomains(
                    userid => $hostowner,
                    host   => $host,
                    type   => $hosttype,
                    flag   => $nametype,
                    action => "delete",
                )
                )
            {
                return 1;
            }
        }
    }
    else    # any other name type
    {
        if ($self->CheckAllDomains(
                userid => $userid,
                host   => $host,
                type   => $hosttype,
                flag   => $nametype,
                action => "delete",
            )
            )
        {
            return 1;
        }
    }

    return 0;
}

# Begin-Doc
# Name: CheckHostEditAccess
# Type: function
# Description: Checks if a particular userid is allowed to edit a host
# Syntax: $res = $obj->CheckHostEditAccess(userid => $userid, host => $host)
# Comments: $res is nonzero if edit access is approved
# End-Doc
sub CheckHostEditAccess {
    my $self   = shift;
    my %opts   = @_;
    my $userid = $opts{userid} || $ENV{REMOTE_USER} || return 0;
    my $host   = lc $opts{host} || return 0;
    my $action = $opts{action} || "update";

    my %privs = &PrivSys_FetchPrivs($userid);

    my $obo      = $privs{"netdb-admin"};
    my $nametype = $self->GetHostNameType($host);

    if ( $privs{"sysprog:netdb"} ) {
        return 1;
    }

    # Look up the type of this host
    my $db = $self->{db};
    my ( $qry, $cid );
    $qry = "select type,owner,adminlock from hosts where host=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && return 0;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return 0;
    my ( $hosttype, $hostowner, $hostadminlock ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);
    return 0 if ( !$hosttype );

    if ($hostadminlock) {
        if ( !$privs{"sysprog:netdb:adminlock"} ) {
            return 0;
        }
    }

    # Now check permissions
    if ($self->CheckAllDomains(
            userid => $userid,
            host   => $host,
            type   => $hosttype,
            flag   => $nametype,
            action => $action,
        )
        )
    {
        return 1;
    }

    # Maybe this shouldn't be here... hard to tell
    if ( $hostowner eq $userid ) {
        return 1;
    }

    if ( $hosttype eq "desktop"
        && ( $nametype eq "ownername" ) )
    {
        if ( $obo || ( $hostowner eq $userid ) ) {
            if ($self->CheckAllDomains(
                    userid => $hostowner,
                    host   => $host,
                    type   => $hosttype,
                    flag   => $nametype,
                    action => $action,
                )
                )
            {
                return 1;
            }
        }
    }
    else    # any other name type
    {
        if ($self->CheckAllDomains(
                userid => $userid,
                host   => $host,
                type   => $hosttype,
                flag   => $nametype,
                action => $action,
            )
            )
        {
            return 1;
        }
    }

    return 0;
}

# Begin-Doc
# Name: CheckHostViewAccess
# Type: function
# Description: Checks if a particular userid is allowed to view a host
# Syntax: $res = $obj->CheckHostEditAccess(userid => $userid, host => $host)
# Comments: $res is nonzero if edit access is approved
# End-Doc
sub CheckHostViewAccess {
    my $self   = shift;
    my %opts   = @_;
    my $userid = $opts{userid} || $ENV{REMOTE_USER} || return 0;
    my $host   = lc $opts{host} || return 0;

    my %privs = &PrivSys_FetchPrivs($userid);

    my $obo      = $privs{"netdb-admin"};
    my $viewany  = $privs{"sysprog:netdb:view-any"};
    my $nametype = $self->GetHostNameType($host);

    if ( $viewany || $privs{"sysprog:netdb"} ) {
        return 1;
    }

    # Look up the type of this host
    my $db = $self->{db};
    my ( $qry, $cid );
    $qry = "select type,owner from hosts where host=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && return 0;
    $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry) && return 0;
    my ( $hosttype, $hostowner ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);
    return 0 if ( !$hosttype );

    # Now check permissions
    if ($self->CheckAllDomains(
            userid => $userid,
            host   => $host,
            type   => $hosttype,
            flag   => $nametype,
            action => "view",
        )
        )
    {
        return 1;
    }

    if ( $hostowner eq $userid ) {
        return 1;
    }

    if ( $hosttype eq "desktop"
        && ( $nametype eq "ownername" ) )
    {
        if ( $obo || ( $hostowner eq $userid ) ) {
            if ($self->CheckAllDomains(
                    userid => $hostowner,
                    host   => $host,
                    type   => $hosttype,
                    flag   => $nametype,
                    action => "view",
                )
                )
            {
                return 1;
            }
        }
    }
    else    # any other name type
    {
        if ($self->CheckAllDomains(
                userid => $userid,
                host   => $host,
                type   => $hosttype,
                flag   => $nametype,
                action => "view",
            )
            )
        {
            return 1;
        }
    }

    return 0;
}

# Begin-Doc
# Name: CheckAllDomains
# Type: function
# Description: Runs Check for all possible domains of a host
# Syntax: $res = $obj->CheckAllDomains(%opts)
# Comments: $res is nonzero if a row matches, opts contains optional keys
# type, host, subnet, flag, action. Any specified must match. Should specify
# host instead of domain.
# End-Doc
sub CheckAllDomains {
    my $self   = shift;
    my %opts   = @_;
    my $host   = $opts{host};
    my $userid = $opts{userid} || $ENV{REMOTE_USER} || undef;
    delete $opts{host};
    delete $opts{domain};

    my %privs = &PrivSys_FetchPrivs($userid);

    if ( $privs{"sysprog:netdb"} ) {
        return 1;
    }

    # Get a list of possible domain names for this host
    my @splitname = split( /\./, $host );
    my @hostdomains = ();

    # for a.b.c.d, check b.c.d, c.d, and then a.b.c.d for perms
    for ( my $i = 0; $i < $#splitname; $i++ ) {
        my @tmp = @splitname[ $i .. $#splitname ];
        push( @hostdomains, join( ".", @tmp ) );
    }

    # move full hostname to the end for efficiency
    push( @hostdomains, shift @hostdomains );

    foreach my $domain (@hostdomains) {
        if ( $self->Check( %opts, domain => $domain ) ) {
            return 1;
        }
    }

    return 0;
}

# Begin-Doc
# Name: Check
# Type: function
# Description: Checks access rules for a matching row
# Syntax: $res = $obj->Check(%opts)
# Comments: $res is nonzero if a row matches, opts contains optional keys
# type, domain, subnet, flag, action. Any specified must match.
# End-Doc
sub Check {
    my $self     = shift;
    my %opts     = @_;
    my $q_userid = $opts{userid} || $ENV{REMOTE_USER} || return 0;
    my $q_domain = $opts{domain};
    my $q_subnet = $opts{subnet};
    my $q_flag   = $opts{flag};
    my $q_type   = $opts{type};
    my $q_action = $opts{action};

    my $ad = $self->{access_data};

    my %privs = &PrivSys_FetchPrivs($q_userid);

    $self->LoadUserAccessData($q_userid);
    $self->LoadUserAccessData("public");

    if ( $privs{"sysprog:netdb"} ) {
        return 1;
    }

    if (   !$q_userid
        && !$q_domain
        && !$q_subnet
        && !$q_flag
        && !$q_type
        && !$q_action )
    {
        return 0;
    }

    foreach my $row ( @{$ad} ) {
        my ( $userid, $type, $domain, $subnet, $flag, $action ) = @{$row};
        next if ( $q_userid ne $userid && $userid ne "public" );
        next if ( $q_type   && $q_type   ne $type   && $type   ne "*" );
        next if ( $q_domain && $q_domain ne $domain && $domain ne "*" );
        next if ( $q_subnet && $q_subnet ne $subnet && $subnet ne "*" );
        next if ( $q_flag   && $q_flag   ne $flag   && $flag   ne "*" );
        next if ( $q_action && $q_action ne $action && $action ne "*" );
        return 1;
    }

    return 0;
}

# Begin-Doc
# Name: ExpandRule
# Type: function
# Description: Expands a rule from access_rules into access_data
# Syntax: $obj->ExpandRule($rule_id)
# End-Doc
sub ExpandRule {
    my $self  = shift;
    my $id    = shift;
    my $db    = $self->{db};
    my $debug = 0;
    my $rule  = $self->GetRule($id);
    my ( $qry, $cid );

    if ( !$rule ) { return; }

    my @want_data;
    my %want_key;

    # Determine a user list
    $debug && print "generating user list for rule id $id...\n";
    my @who = split( /,/, $rule->{who} );
    my @users = ();
    foreach my $whoent (@who) {
        if ( $whoent =~ /^\@(.*?)\s*$/o ) {
            # Not supported currently, ignore
        }
        elsif ( $whoent !~ /^\@/o ) {
            push( @users, $whoent );
        }
    }

    # If nulls, make blanks
    $debug && print "generating expanded ruleset for rule id $id...\n";

    my ( @domains, @types, @flags, @subnets, @actions );
    @domains = split( /,/, $rule->{domains} );
    @subnets = split( /,/, $rule->{subnets} );
    @flags   = split( /,/, $rule->{flags} );
    @types   = split( /,/, $rule->{types} );
    @actions = split( /,/, $rule->{actions} );
    if ( $#domains < 0 ) { @domains = (''); }
    if ( $#subnets < 0 ) { @subnets = (''); }
    if ( $#flags < 0 )   { @flags   = (''); }
    if ( $#types < 0 )   { @types   = (''); }
    if ( $#actions < 0 ) { @actions = (''); }

    # Insert new entries
    my ( $userid, $domain, $type, $flag, $who, $subnet, $action );
    foreach $userid (@users) {
        $debug && print "$userid\n";
        foreach $domain (@domains) {
            $debug && print " $domain\n";
            foreach $type (@types) {
                $debug && print "  $type\n";
                foreach $flag (@flags) {
                    $debug && print "    $flag\n";
                    foreach $subnet (@subnets) {
                        $debug && print "    $subnet\n";

                        foreach $action (@actions) {
                            $debug && print "    $action\n";

                            my @row = ( $userid, $type, $domain, $subnet, $flag, $action );
                            my $key = join( "\0", @row );
                            push( @want_data, [@row] );
                            $want_key{$key} = 1;
                        }
                    }
                }
            }
        }
    }

    $debug && print "done generating expanded ruleset for rule id $id.\n";

    my %have_key;

    my $cache = $self->{cache};

    my $delqry = "delete from access_data where dataid=?";
    my $delcid = $cache->open($delqry)
        || $db->SQL_Error($delqry) && return undef;

    # Insert query
    my $insqry
        = "insert into access_data(id,updateflag,userid,type,domain,subnet,flag,action) values (?,1,?,?,?,?,?,?)";
    my $inscid = $cache->open($insqry)
        || $db->SQL_Error($qry) && return undef;

    $qry = "select distinct dataid, userid, type, domain, subnet, flag, action from access_data where id=?";
    my $cid = $cache->open($qry) || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, int($id) )
        || $db->SQL_Error($qry) && return undef;
    while ( my ( $dataid, $userid, $type, $domain, $subnet, $flag, $action ) = $db->SQL_FetchRow($cid) ) {
        my @row = ( $userid, $type, $domain, $subnet, $flag, $action );
        my $rowtext = join( ", ", @row );
        my $key     = join( "\0", @row );

        if ( !$want_key{$key} ) {
            $debug && print "removing row: $rowtext\n";
            $db->SQL_ExecQuery( $delcid, $dataid )
                || $db->SQL_Error( $delqry . " ($rowtext)" ) && return undef;
        }
        else {
            $have_key{$key} = 1;
        }
    }

    foreach my $row (@want_data) {
        my @row     = @$row;
        my $rowtext = join( ", ", @row );
        my $key     = join( "\0", @row );

        if ( !$have_key{$key} ) {
            $debug && print "insert row: $rowtext\n";
            $db->SQL_ExecQuery( $inscid, int($id), @row )
                || $db->SQL_Error( $insqry . " ($rowtext)" ) && return undef;
        }
    }

    $debug && print "done expanding rule id $id.\n";
}

# Begin-Doc
# Name: GetDefaultRegistrationQuota
# Type: method
# Description: Retrieves default registration quota for a userid
# Syntax: $cnt = $obj->GetDefaultRegistrationQuota($owner)
# End-Doc
sub GetDefaultRegistrationQuota {
    my $self   = shift;
    my $userid = lc shift;

    return 1000;
}

# Begin-Doc
# Name: GetRegistrationQuota
# Type: method
# Description: Retrieves registration quota for a userid
# Syntax: $cnt = $obj->GetRegistrationQuota($owner)
# End-Doc
sub GetRegistrationQuota {
    my $self   = shift;
    my $userid = lc shift;
    my ( $qry, $cid );
    my $db = $self->{db};

    $qry = "select owner,quota from quota where owner=?";
    $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && return 0;
    $db->SQL_ExecQuery( $cid, $userid ) || $db->SQL_Error($qry) && return 0;
    my ( $qowner, $qquota ) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);

    if ( $qowner eq $userid ) {
        return $qquota;
    }

    return $self->GetDefaultRegistrationQuota($userid);
}

# Begin-Doc
# Name: GetAllRegistrationQuotas
# Type: method
# Description: Retrieves registration quota for all users
# Syntax: $quotas = $obj->GetAllRegistrationQuotas()
# Returns: hash keyed on owner userid value is quota
# End-Doc
sub GetAllRegistrationQuotas {
    my $self = shift;
    my ( $qry, $cid );
    my $db     = $self->{db};
    my $quotas = {};

    $qry = "select owner,quota from quota";
    $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
    while ( my ( $owner, $quota ) = $db->SQL_FetchRow($cid) ) {
        $quotas->{$owner} = $quota;
    }
    $db->SQL_CloseQuery($cid);

    return $quotas;
}

# Begin-Doc
# Name: DeleteRegistrationQuota
# Type: method
# Description: Deletes registration quota for a user
# Syntax: $obj->DeleteRegistrationQuota($userid)
# End-Doc
sub DeleteRegistrationQuota {
    my $self  = shift;
    my $owner = lc shift;
    my ( $qry, $cid );
    my $db = $self->{db};

    $qry = "delete from quota where owner=?";
    $db->SQL_ExecQuery( $qry, $owner ) || $db->SQL_Error($qry) && die;
}

# Begin-Doc
# Name: UpdateRegistrationQuota
# Type: method
# Description: Updates registration quota for a user
# Syntax: $obj->UpdateRegistrationQuota($userid, $quota)
# End-Doc
sub UpdateRegistrationQuota {
    my $self  = shift;
    my $owner = lc shift;
    my $quota = int(shift);

    my ( $qry, $cid );
    my $db = $self->{db};

    $qry = "delete from quota where owner=?";
    $db->SQL_ExecQuery( $qry, $owner ) || $db->SQL_Error($qry) && die;

    $qry = "insert into quota (owner,quota) values (?,?)";
    $db->SQL_ExecQuery( $qry, $owner, $quota ) || $db->SQL_Error($qry) && die;
}

# Begin-Doc
# Name: GetUsedQuota
# Type: method
# Description: Returns amount of quota in use for a user
# Syntax: $cnt = $obj->GetUsedQuota($userid);
# End-Doc
sub GetUsedQuota {
    my $self   = shift;
    my $userid = shift;

    my $db = $self->{db};
    my ( $qry, $cid );

    if ( !$userid ) {
        return 0;
    }

    $qry = "select count(*) from hosts,ethers where hosts.owner=? and hosts.host=ethers.name";
    $cid = $db->SQL_OpenBoundQuery($qry)
        || $db->SQL_Error($qry) && return undef;
    $db->SQL_ExecQuery( $cid, $userid )
        || $db->SQL_Error($qry) && return undef;

    my ($cnt) = $db->SQL_FetchRow($cid);

    $db->SQL_CloseQuery($cid);

    return $cnt;
}

# Begin-Doc
# Name: IsUnderQuota
# Type: method
# Description: Returns non-zero if user is under their registration quota
# Syntax: $res = $obj->IsUnderQuota($userid)
# End-Doc
sub IsUnderQuota {
    my $self  = shift;
    my $userid = lc shift;

    my $quota = $self->GetRegistrationQuota($userid);
    my $used  = $self->GetUsedQuota($userid);

    if ( defined($used) && $used < $quota ) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
