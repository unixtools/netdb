# Begin-Doc
# Name: NetMaint::HostSeen
# Type: module
# Description: object to hold routines for determining the most recent subnets a host has been seen
# End-Doc

package NetMaint::HostSeen;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require NetMaint::DB;
require NetMaint::Util;
require NetMaint::DBCache;
require NetMaint::DHCP;
require NetMaint::Network;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::HostSeen()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db}      = new NetMaint::DB;
    $tmp->{util}    = new NetMaint::Util;
    $tmp->{dbcache} = new NetMaint::DBCache;
    $tmp->{dhcp}    = new NetMaint::DHCP;
    $tmp->{network} = new NetMaint::Network;


    return bless $tmp, $class;
}

# Begin-Doc
# Name: GetHostLastSeen
# Type: method
# Description: Returns info on last place a host was seen
# Syntax: $info = $obj->GetHostLastSeen($host)
# Comments: %keys can have 'host' or 'ether'
# Returns: $info is hash reference with keys 'tstamp', 'subnet', 'ip', 'ether'
# End-Doc
sub GetHostLastSeen {
    my $self = shift;
    my $host = shift;

    my $info = $self->GetHostSeen($host);
    if ( !$info ) {
        return undef;
    }

    my @entries = @$info;
    my @sorted = sort { $b->{tstamp} cmp $a->{tstamp} } @entries;
    return $sorted[0];
}

# Begin-Doc
# Name: GetHostSeen
# Type: method
# Description: Returns info on all places a host has been seen
# Syntax: $info = $obj->GetHostSeen($host)
# Comments: %keys can have 'host' or 'ether'
# Returns: $info is an array ref pointing at hashes with keys 'tstamp', 'subnet', 'ip', 'ether'
# Comments: Returned array is not sorted.
# End-Doc
sub GetHostSeen {
    my $self   = shift;
    my $host   = shift;
    my %ethers = ();
    my $debug  = 0;

    $debug && print "scanning for $host\n";

    # First get list of ethers registered to the host
    my $dhcp = $self->{dhcp};
    my $util = $self->{util};
    foreach my $eth ( $dhcp->GetEthers($host) ) {
        my $ceth = $util->CondenseEther($eth);
        $ethers{$ceth} = 1;
        $debug && print "got eth $ceth\n";
    }

    # Now get the list of static IPs assigned to the host
    my $network = $self->{network};
    my @ips     = $network->GetHostAddresses($host);

    # Now, for each distinct ethernet address we've found, scan through all the various tables
    # to find recent data
    my $cache = $self->{dbcache};
    my $db    = $self->{db};
    my %res;
    my %ip_to_subnet;

    foreach my $tbl ( "arpscan", "dhcp_acklog", "dhcp_curleases", "dhcp_lastack" ) {
        my $qry = "select ip, tstamp from $tbl where ether=?";
        my $cid = $cache->open($qry);

        foreach my $ether ( keys(%ethers) ) {
            $db->SQL_ExecQuery( $cid, $ether ) || return undef;
            $debug && print "scanning for $ether in tbl $tbl\n";

            while ( my ( $ip, $ts ) = $db->SQL_FetchRow($cid) ) {
                my $key = join( "---", $ether, $ip, $ts );
                $debug && print "found $ip / $ts\n";

                if ( !$ip_to_subnet{$ip} ) {
                    my %info = $network->GetAddressDetail($ip);
                    $ip_to_subnet{$ip} = $info{subnet};
                }

                $res{$key} = {
                    ip     => $ip,
                    tstamp => $ts,
                    ether  => $ether,
                    subnet => $ip_to_subnet{$ip}
                };
            }
        }
    }

    return [ values(%res) ];
}

1;
