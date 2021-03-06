# Begin-Doc
# Name: NetMaint::Register
# Type: module
# Description: object to handle registration transactions and rollback
# End-Doc

package NetMaint::Register;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::UsageLogger;
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

    &LogAPIUsage();

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

1;
