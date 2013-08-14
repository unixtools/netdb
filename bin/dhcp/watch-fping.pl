#!/usr/bin/perl

# Begin-Doc
# Name: watch-fping.pl
# Type: script
# Description: continuously watch fping of various subnets
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/netdb/libs";
use Local::SetUID;
require NetMaint::DB;
use Sys::Hostname;
use Net::IP;

&SetUID("netdb");

my $server = hostname;
$server =~ s|\..*||gio;

my @targets = @ARGV;
if ( scalar(@targets) == 0 )
{
    # Grab from locally attached networks
    open(my $route, "-|") || exec("netstat", "-rn");
    while ( defined(my $routeline = <$route>) )
    {
        if ( $routeline =~ m|^([\d\.]+)\s+0\.0\.0\.0\s+([\d\.]+)| )
        {
            my $ip = $1;
            my $mask = $2;

            if ( $mask eq "255.255.255.0" )
            {
                push(@targets, "$1/24");
            }
        }

#Kernel IP routing table
#Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
#0.0.0.0         10.155.2.1      0.0.0.0         UG        0 0          0 eth0
#10.155.0.0      0.0.0.0         255.255.255.0   U         0 0          0 eth1
#169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 eth2
    }
    close($route);
}



my $debug = 0;
open( STDERR, ">&STDOUT" );

# Should never go 2 minutes stuck in a call
# Disabled at spirent, dhcp traffic is low
my $max_idle = 120;
alarm($max_idle);

$SIG{PIPE} = "die";

#
# Connect to db
#
my $db  = new NetMaint::DB;
my $qry = "replace into last_ping_ip(ip,ether,source,tstamp) values (?,?,?,now())";
my $cid = $db->SQL_OpenBoundQuery($qry) || $db->SQL_Error($qry) && die;

#
# Generate list of addresses from the targets
#
my $tf = "/tmp/fping-ip-list-$$-" . time;
my @ips;
foreach my $target (@targets) {
    my $ip = new Net::IP($target);
    do {
        push( @ips, $ip->ip() );
    } while ( ++$ip );
}
unlink($tf);
open(my $out, ">$tf");
print $out join("\n", @ips);
close($out);

my $lastarp;
my %ip_to_ether = ();

my $ping_count = 0;
my $last_count_print = time;

open(SV_STDIN, ">&STDIN");
open(STDIN, "<$tf");
unlink($tf);
open( my $in, "-|" ) || exec( "fping", "-c", "10", "-p", "30000", "-q" );
open(STDIN, ">&SV_STDIN");

# Give fping a head start so that arp table will populate
sleep(30);

while ( defined( my $line = <$in> ) ) {
    chomp($line);
    $debug && print $line, "\n";

    # Clear on each pass
    %ip_to_ether = ();
    if ( time - $lastarp > 15 ) {
        open( my $arp, "-|" ) || exec( "arp", "-an" );
        while ( defined( my $arpline = <$arp> ) ) {

            next if ( $arpline =~ /incomplete/o );

            # (10.155.2.161) at 00:1b:21:bf:6f:b4 [ether] on eth0
            if ( $arpline =~ m|.*\(([0-9\.]+)\) at ([0-9a-f:]+) | ) {
                $ip_to_ether{$1} = $2;
            }
        }
        close($arp);

        $lastarp = time;
    }

    # 10.155.2.228 : [0], 84 bytes, 0.33 ms (0.33 avg, 0% loss)
    if ( $line =~ /^([0-9\.]+)\s+:.*bytes,\s+\d/o ) {
        my $ip    = $1;
        # don't insert nulls
        my $ether = $ip_to_ether{$ip} || "00:00:00:00:00:00";

        $db->SQL_ExecQuery( $cid, $ip, $ether, $server ) || $db->SQL_Error("inserting $ip, $ether: $qry") && die;
        $ping_count++;

        # Extend timeout
        alarm($max_idle);
    }

    if ( time - $last_count_print > 30 )
    {
        print "Ping Count: $ping_count\n";
        $last_count_print = time;
    }
}
close($in);

