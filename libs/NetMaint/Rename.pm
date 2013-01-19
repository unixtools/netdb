# Begin-Doc
# Name: NetMaint::Rename
# Type: module
# Description: special object that does the function of renaming a host only
# End-Doc

package NetMaint::Rename;
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
# Syntax: $maint = new NetMaint::Rename()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}    = new NetMaint::DB;
    $tmp->{util}  = new NetMaint::Util;
    $tmp->{log}   = new NetMaint::Logging;
    $tmp->{touch} = new NetMaint::LastTouch;
    $tmp->{dhcp}  = new NetMaint::DHCP;
    $tmp->{dns}   = new NetMaint::DNS;


    return bless $tmp, $class;
}

# Begin-Doc
# Name: RenameHost
# Type: function
# Description: Renames a machine name and possibly changes owner at same time
# Syntax: $res = $obj->RenameHost(%opts)
# Comments: %opts has keys oldhost,newhost,newowner,newtype
# Returns: undef on success, error message otherwise
# End-Doc
sub RenameHost {
    my $self  = shift;
    my %opts  = @_;
    my $util  = $self->{util};
    my $db    = $self->{db};
    my $log   = $self->{log};
    my $touch = $self->{touch};
    my $dhcp  = $self->{dhcp};
    my $dns   = $self->{dns};

    my $debug = 0;

    my $oldhost  = lc $opts{oldhost}  || return "must specify old hostname";
    my $newhost  = lc $opts{newhost}  || return "must specify new hostname";
    my $newowner = lc $opts{newowner} || return "must specify new owner";
    my $newtype  = lc $opts{newtype}  || return "must specify new type";
    my $skip_cnames = $opts{skip_cnames};

    $debug && print "Attempting rename of '$oldhost' to '$newhost'.\n";
    $debug && print "New type '$newtype' and new owner '$newowner'.\n";

    my $newzone = $dns->Get_Host_Zone($newhost);
    if ( !$newzone ) {
        return "Unable to determine new host zone for ($newhost).\n";
    }

    # Build table list
    my @tables = qw(
        admin_host_options
        dhcp_host_options
        dns_a
        dns_aaaa
        dns_cname
        dns_mx
        dns_ns
        dns_ptr
        dns_srv
        dns_txt
        dns_soa
        ethers
        hosts
        ip_alloc
        log
    );
    my $tablelist = join( ",", @tables );

    my @locklist;
    foreach my $tbl (@tables) {
        push( @locklist, "$tbl write" );
    }
    my $locklist = join( ", ", @locklist );

#
# NOTE - this needs to be enhanced for more failure checking, not currently using transactions with mysql, though could if I determine
# that is the best route
#

    # Lock tables
    $debug && print "Locking tables ($tablelist) in exclusive mode.\n";
    my $qry = "lock tables $locklist";
    $debug && print "Attempting query: $qry\n";
    unless ( $db->SQL_ExecQuery($qry) ) {
        my $err = $db->SQL_ErrorString($qry);

        $db->SQL_ExecQuery("unlock tables");

        $log->Log(
            action => "failed to rename to $newhost",
            host   => $oldhost,
            msg    => "lock failure: $err"
        );
        return "failed to lock tables: $err";
    }
    $debug && print "Lock obtained.\n";

    # Select from both to make sure old host exists and new host does not exist
    $debug && print "Searching for old hostname.\n";
    my $qry   = "select count(*) from hosts where host=?";
    my $cid   = $db->SQL_OpenQuery( $qry, $oldhost ) || $db->SQL_Error($qry) && die;
    my ($cnt) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);
    if ( $cnt != 1 ) {
        $debug && print "Error - old hostname '$oldhost' not found.\n";

        $db->SQL_ExecQuery("unlock tables");

        $log->Log(
            action => "failed to rename to $newhost",
            host   => $oldhost,
            msg    => "old hostname does not exist"
        );
        return "old hostname '$oldhost' not found";
    }
    else {
        $debug && print "Found old hostname '$oldhost'.\n";
    }

    $debug && print "Searching for new hostname.\n";
    my $qry   = "select count(*) from hosts where host=" . $db->SQL_QuoteString($newhost);
    my $cid   = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
    my ($cnt) = $db->SQL_FetchRow($cid);
    $db->SQL_CloseQuery($cid);
    if ( $cnt != 0 ) {
        $debug && print "Error - new hostname '$newhost' exists.\n";
        $db->SQL_ExecQuery("unlock tables");

        $log->Log(
            action => "failed to rename to $newhost",
            host   => $oldhost,
            msg    => "new hostname exists"
        );
        return "new hostname '$newhost' exists";
    }
    else {
        $debug && print "New hostname '$newhost' is available.\n";
    }

    # Determine domain name from the old and new hostnames
    my $newdomain = $newhost;
    $newdomain =~ s|^.*?\.||gio;
    $debug && print "New domain is '$newdomain'.\n";

    # Build up a list of queries
    my @queries = ();

    push( @queries,
              "update admin_host_options set tstamp=now(),host="
            . $db->SQL_QuoteString($newhost)
            . " where host="
            . $db->SQL_QuoteString($oldhost) );
    push( @queries,
              "update dhcp_host_options set tstamp=now(),host="
            . $db->SQL_QuoteString($newhost)
            . " where host="
            . $db->SQL_QuoteString($oldhost) );
    foreach my $table (@tables) {
        next if ( $table !~ /^dns_/o );
        next if ( $table =~ /^dns_soa/o );
        if ( $table =~ /ptr/io ) {
            push( @queries,
                      "update $table set mtime=now(),address="
                    . $db->SQL_QuoteString($newhost)
                    . " where address="
                    . $db->SQL_QuoteString($oldhost) );
        }
        else {
            push( @queries,
                      "update $table set mtime=now(),name="
                    . $db->SQL_QuoteString($newhost)
                    . ",zone="
                    . $db->SQL_QuoteString($newzone)
                    . " where name="
                    . $db->SQL_QuoteString($oldhost) );
        }
    }
    push( @queries,
        "update ethers set name=" . $db->SQL_QuoteString($newhost) . " where name=" . $db->SQL_QuoteString($oldhost) );
    push( @queries,
              "update ip_alloc set host="
            . $db->SQL_QuoteString($newhost)
            . " where host="
            . $db->SQL_QuoteString($oldhost) );
    push( @queries,
              "update hosts set host="
            . $db->SQL_QuoteString($newhost)
            . ", domain="
            . $db->SQL_QuoteString($newdomain)
            . ", type="
            . $db->SQL_QuoteString($newtype)
            . ", owner="
            . $db->SQL_QuoteString($newowner)
            . ", mtime=now(), modifiedby="
            . $db->SQL_QuoteString($ENV{REMOTE_USER} || "netdb")
            . " where host="
            . $db->SQL_QuoteString($oldhost) );

    unless ($skip_cnames) {
        push( @queries,
                  "update dns_cname set address="
                . $db->SQL_QuoteString($newhost)
                . " where address="
                . $db->SQL_QuoteString($oldhost) );
    }

    foreach my $qry (@queries) {
        $debug && print "Attempting query: $qry\n";

        unless ( $db->SQL_ExecQuery($qry) ) {
            my $err = $db->SQL_ErrorString($qry);

            $debug
                && print
                "Update query ($qry) failed: $err - submit ticket with information, host may be in indeterminate state";

            $log->Log(
                action => "failed to rename to $newhost",
                host   => $oldhost,
                msg    => $err,
            );

            return "Update query ($qry) failed: $err";
        }
        else {
            $debug && print "Query completed ok.\n";
        }
    }

    $db->SQL_ExecQuery("unlock tables");

    # Update last touch for old hostname and new hostname
    $touch->UpdateLastTouch( host => $oldhost );
    $touch->UpdateLastTouch( host => $newhost );

    # Add log entry for old hostname and new hostname
    $log->Log(
        action => "renamed to $newhost",
        host   => $oldhost,
        owner  => $newowner,
        type   => $newtype,
        msg    => "host renamed",
    );
    $log->Log(
        action => "renamed from $oldhost",
        host   => $newhost,
        owner  => $newowner,
        type   => $newtype,
        msg    => "host renamed",
    );

    $dhcp->TriggerUpdate();

    return undef;
}

1;

