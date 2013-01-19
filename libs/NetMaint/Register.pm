# Begin-Doc
# Name: NetMaint::Register
# Type: module
# Description: object to handle registration transactions and rollback
# End-Doc

package NetMaint::Register;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require NetMaint::DB;
require NetMaint::Util;
require NetMaint::DHCP;
require NetMaint::Network;
require NetMaint::Hosts;
require NetMaint::DNS;
require NetMaint::Logging;
require NetMaint::LastTouch;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Register()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}    = new NetMaint::DB;
    $tmp->{util}  = new NetMaint::Util;
    $tmp->{log}   = new NetMaint::Logging;
    $tmp->{touch} = new NetMaint::LastTouch;


    return bless $tmp, $class;
}

# Begin-Doc
# Name: DeleteHost
# Type: function
# Description: Completely removes registration and all extra info for a host
# Syntax: $res = $obj->DeleteHost($host)
# Returns: undef on success, error message otherwise
# End-Doc
sub DeleteHost {
    my $self = shift;
    my $host = lc shift;
    my $util = $self->{util};
    my $db   = $self->{db};
    my $log  = $self->{log};

    # Delete in order of dependancy in terms of resource usage

    my $dhcp = new NetMaint::DHCP;
    $dhcp->DeleteHost($host);

    my $dns = new NetMaint::DNS;
    $dns->DeleteHost($host);

    my $network = new NetMaint::Network;
    $network->DeleteHost($host);

    my $hosts = new NetMaint::Hosts;
    $hosts->DeleteHost($host);

    $log->Log(
        action => "deleted host",
        host   => $host,
    );

    return undef;
}

# Begin-Doc
# Name: RegisterDesktop
# Type: function
# Description: Registers a new desktop machine name and single ethernet address
# Syntax: $res = $obj->RegisterDesktop(%opts)
# Comments: %opts has keys hostname, domain, owner, ether, type
# Returns: undef on success, error message otherwise
# Comments: this routine expects to be handed good data, it just does the work of registering the host
# End-Doc
sub RegisterDesktop {
    my $self = shift;
    my %opts = @_;
    my $util = $self->{util};
    my $db   = $self->{db};
    my $log  = $self->{log};

    my $host   = lc $opts{host};
    my $domain = lc $opts{domain};
    my $owner  = lc $opts{owner};
    my $ether  = $util->CondenseEther( $opts{ether} );
    my $type   = lc $opts{type} || "desktop";

    my $dhcp = new NetMaint::DHCP;

    my ( $qry, $cid );

    # These need changes to called hosts and dhcp apis!

    # First register the host name
    $qry = "insert into hosts(host,domain,type,owner,ctime,mtime,modifiedby) values (?,?,?,?,now(),now(),?)";
    my $res = $db->SQL_ExecQuery( $qry, $host, $domain, $type, $owner, $ENV{REMOTE_USER} );

    if ( !$res ) {
        $log->Log(
            action => "register $type",
            host   => $host,
            owner  => $owner,
            ether  => $ether,
            msg    => "failed to register host name",
        );

        # insert failed... no rollback here though since on first query
        return "failed to register host name";
    }

    # First register the host name
    $qry = "insert into ethers(name,ether) values (?,?)";
    my $res = $db->SQL_ExecQuery( $qry, $host, $ether );

    if ( !$res ) {

        # insert failed... since we just registered host name, we need to roll back
        $qry = "delete from hosts where host=?";
        $db->SQL_ExecQuery( $qry, $host );

        $log->Log(
            action => "register $type",
            host   => $host,
            owner  => $owner,
            ether  => $ether,
            msg    => "failed to register ethernet address",
        );

        return "failed to register ethernet address";
    }

    $log->Log(
        action => "register $type",
        host   => $host,
        owner  => $owner,
        ether  => $ether,
        msg    => "registration completed",
    );

    $self->{touch}->UpdateLastTouch( host => $host, ether => $ether );

    $dhcp->TriggerUpdate();

    return undef;
}

1;
