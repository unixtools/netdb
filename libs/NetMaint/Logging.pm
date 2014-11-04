# Begin-Doc
# Name: NetMaint::Logging
# Type: module
# Description: object to manage access logging
# End-Doc

package NetMaint::Logging;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require NetMaint::DB;
require NetMaint::Util;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Logging()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}   = new NetMaint::DB;
    $tmp->{util} = new NetMaint::Util;


    return bless $tmp, $class;
}

# Begin-Doc
# Name: Log
# Type: method
# Description: Adds an entry to the access log
# Syntax: $obj->Log(%info)
# Comments: %info has (all optional) keys: owner, action, host, ether, address, msg, status
# End-Doc
sub Log {
    my $self = shift;
    my %info = @_;

    my $util = $self->{util};

    # Don't log from this app, will generate far too much data
    return if ( $0 =~ /process-dhcp-netdb-logs.pl/o );

    my $owner 
        = $info{owner}
        || $main::rqpairs{owner}
        || $main::rqpairs{oldowner}
        || $main::rqpairs{newowner};
    my $action = $info{action} || $main::rqpairs{mode};
    my $host 
        = $info{host}
        || $info{name}
        || $main::rqpairs{host}
        || $main::rqpairs{name}
        || $main::rqpairs{oldhost}
        || $main::rqpairs{newhost};
    my $ether = $info{ether} || $main::rqpairs{ether};
    my $address 
        = $info{address}
        || $info{ip}
        || $main::rqpairs{ip}
        || $main::rqpairs{address};
    my $status = $info{status};
    my $msg = $info{msg} || "";

    my ( $function_module, $function_basefile, $function_line, $function_name ) = caller(1);
    my $function = $function_module . "::" . $function_name;
    if ( $function eq "::" ) { $function = ""; }

    my %others = @_;
    my $key;
    foreach $key (qw(owner action host ether address ip status msg)) {
        delete $others{$key};
    }
    foreach $key ( sort( keys(%others) ) ) {
        $msg .= " [$key=" . $others{$key} . "]";
    }

    my $userid = $ENV{REMOTE_USER};
    my $app    = $0;

    $owner   = lc $owner;
    $host    = lc $host;
    $ether   = $util->CondenseEther($ether);
    $address = $util->CondenseIP($address);
    $app =~ s|.*/||gio;

    my ( $qry, $cid );
    my $db = $self->{db};

    if ( !$self->{logcid} ) {
        my $qry = "insert into log(tstamp,app,function,action,userid,owner,host,ether,address,status,msg) "
            . "values (now(),?,?,?,?,?,?,?,?,?,?)";

        $self->{logcid} = $db->SQL_OpenBoundQuery($qry);
    }
    my $logcid = $self->{logcid};

    $db->SQL_ExecQuery( $logcid, $app, $function, $action, $userid, $owner, $host, $ether, $address, $status, $msg )
        || $db->SQL_Error($qry) && die;
}

1;
