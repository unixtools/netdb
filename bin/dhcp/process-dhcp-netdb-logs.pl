#!/usr/bin/perl

# Begin-Doc
# Name: process-dhcp-netdb-logs.pl
# Type: script
# Description: process the dhcp netdb logs and run dynamic dns update operations
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use Local::SetUID;
require NetMaint::Leases;
require NetMaint::DNS;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::Access;
use POSIX ":sys_wait_h";

use Time::HiRes qw(time);
use Sys::Hostname;

&SetUID("netdb");

my $base = "/local/dhcp-root/netdb-logs";

my $server = hostname;
$server =~ s|\..*||gio;

my $debug = 0;
open( STDERR, ">&STDOUT" );

my $max_idle = 30 * 60;

# Should never go 2 minutes stuck in a call
# Disabled at spirent, dhcp traffic is low
alarm($max_idle);

my $trace    = 0;
my $lastopen = 0;

$SIG{PIPE} = "die";

my $leases;
my $util;
my $dns;
my $dhcp;
my $dns;
my $hosts;
my $access;

while (1) {
    if ( -e "/local/dhcp-root/netdb-logs/restart" ) {
        unlink("/local/dhcp-root/netdb-logs/restart");
        exit;
    }

    if ( time - $lastopen > 600 ) {
        if ( $lastopen != 0 ) {
            print "Closing database connection.\n";
            &NetMaint::DB::CloseDB();
        }

        $leases = new NetMaint::Leases;
        $util   = new NetMaint::Util;
        $dns    = new NetMaint::DNS;
        $dhcp   = new NetMaint::DHCP;
        $hosts  = new NetMaint::Hosts;
        $access = new NetMaint::Access;

        $lastopen = time;
    }

    # get list of files in log dir
    opendir( my $logdir, $base );
    my $filecnt = 0;
    foreach my $file ( sort( readdir($logdir) ) ) {
        next if ( $file !~ /^log\.\d+$/o );

        my @stat = stat("$base/$file");
        my $age  = time - $stat[9];
        if ( ( $age > 30 * 60 ) && $stat[9] ) {
            print "EXPIRED LOG FILE $base/$file (age=${age}s).\n";
            unlink("$base/$file");
            next;
        }

        $filecnt++;
        print "Processing log $base/$file.\n";
        my $stime     = time;
        my $linecount = 0;
        $dns->BlockUpdates();

        open( my $logfh, "$base/$file" );
        while ( chomp( my $line = <$logfh> ) ) {
            $linecount++;
            alarm($max_idle);

            if ( $line =~ m{network ([\d\.]+/\d+): no free leases} ) {
                &handle_no_free_leases( $1, $line );
            }

            if ( $line =~ /^(\d+): DHCPACK on ([\d\.]+) to ([A-Fa-f0-9:]+) via (.*)/o ) {
                &handle_ack( $1, $2, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): DHCPACK on ([\d\.]+) to ([A-Fa-f0-9:]+) \(.*?\) via (.*)/o ) {
                &handle_ack( $1, $2, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): DHCPACK to ([\d\.]+) \(([A-Fa-f0-9:]+)\) via (.*)/o ) {
                &handle_ack( $1, $2, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): DHCPRELEASE of ([\d\.]+) from ([A-Fa-f0-9:]+) via (.*)/o ) {
                &handle_release( $1, $2, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): DHCPRELEASE of ([\d\.]+) from ([A-Fa-f0-9:]+) \(.*?\) via (.*)/o ) {
                &handle_release( $1, $2, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): BOOTREPLY for ([\d\.]+) to .*? \(([A-Fa-f0-9:]+)\) via (.*)$/o ) {
                &handle_bootreply( $1, $2, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): Ignoring unknown BOOTP client ([A-Fa-f0-9:]+) via (.*)/o ) {
                &handle_ignore( $1, $2, $3 );
            }
            elsif ( $line =~ /^(\d+): No applicable record for BOOTP host ([A-Fa-f0-9:]+) via (.*)/o ) {
                &handle_ignore( $1, $2, $3 );
            }
            elsif ( $line =~ /^(\d+): Ignoring unknown client ([A-Fa-f0-9:]+)/o ) {
                &handle_ignore( $1, $2, "" );
            }
            elsif ( $line =~ /^(\d+): DHCPDISCOVER from ([A-Fa-f0-9:]+) via ([\d\.]+): unknown client/o ) {
                &handle_ignore( $1, $2, "" );
            }
            elsif ( $line =~ /^(\d+): DHCPDISCOVER from ([A-Fa-f0-9:]+) via ([\d\.]+): booting disallowed/o ) {
                &handle_ignore( $1, $2, "" );
            }
            elsif ( $line =~ /^(\d+): DHCPREQUEST for ([\d\.]+) from ([A-Fa-f0-9:]+) via (.*): unknown client/o ) {
                &handle_ignore( $1, $3, $4 );
            }
            elsif ( $line =~ /^(\d+): BOOTREQUEST from ([A-Fa-f0-9:]+) via (.*): BOOTP from dynamic client/o ) {
                &handle_ignore( $1, $2, $3 );
            }
            elsif ( $line =~ /^(\d+): DHCPDISCOVER from/ ) {

                # ignore this
            }
            elsif ( $line =~ /^(\d+): DHCPREQUEST for/ ) {

                # ignore this
            }
            elsif ( $line =~ /^(\d+): DHCPINFORM from/ ) {

                # ignore this
            }
            elsif ( $line =~ /^(\d+): DHCPOFFER on/ ) {

                # ignore this
            }
            else {
                print "Unable to handle log line: $line\n";
            }
        }
        close($logfh);

        $dns->UnblockUpdates();
        unlink("$base/$file");

        my $etime = time;

        my $elap = $etime - $stime;
        my $rate = $linecount / $elap;

        printf
            "Processed $base/$file at rate of %.1f lines/sec for $linecount lines.\n",
            $rate;

    }
    closedir($logdir);

    if ( $filecnt == 0 ) {
        sleep 2;
    }

    if ( $ARGV[0] eq "-once" ) {
        print "exiting, single run was requested.\n";
        exit;
    }
}

# Begin-Doc
# Name: handle_release
# Description: helper routine for handling DHCPRELEASE lease requests
# End-Doc
sub handle_release {
    my ( $ts, $ip, $ether, $gw ) = @_;
    my $qry;

    $debug && print "got release for $ip from $ether via $gw\n";

    $trace && print "RRL[";
    $leases->RecordReleasedLease(
        ether => $ether,
        ip    => $ip
    );
    $trace && print "]\n";
}

# Begin-Doc
# Name: handle_ack
# Description: helper routine for handling DHCPACK lease requests
# End-Doc
sub handle_ack {
    my ( $ts, $ip, $ether, $gw ) = @_;
    my $qry;

    $debug && print "sent ack for $ip to $ether via $gw\n";

    my $st = time;
    $trace && print "RNLACK[";
    $leases->RecordNewLease(
        type    => "DHCPACK",
        ether   => $ether,
        ip      => $ip,
        gateway => $gw,
        tstamp  => $ts,
        server  => $server
    );
    my $et = time;
    $trace && print int( ( $et - $st ) * 1000 );
    $trace && print "]\n";
}

# Begin-Doc
# Name: handle_bootreply
# Description: helper routine for handling BOOTREPLY lease requests
# End-Doc
sub handle_bootreply {
    my ( $ts, $ip, $ether, $gw ) = @_;

    $debug && print "sent bootreply for $ip to $ether via $gw\n";

    $trace && print "RNLBR[";
    $leases->RecordNewLease(
        server  => $server,
        gateway => $gw,
        ether   => $ether,
        ip      => $ip,
        tstamp  => $ts,
        type    => "BOOTREPLY",
    );
    $trace && print "]\n";
}

# Begin-Doc
# Name: handle_ignore
# Description: helper routine for handling ignored lease requests
# End-Doc
sub handle_ignore {
    my ( $ts, $ether, $gw ) = @_;

    $debug && print "got ignore for $ether via $gw\n";

    $trace && print "RIL[";
    $leases->RecordIgnoredLease(
        server  => $server,
        tstamp  => $ts,
        ether   => $ether,
        gateway => $gw,
    );
    $trace && print "]\n";
}

{
    my %last_notify_no_free = ();

    # Begin-Doc
    # Name: handle_no_free_leases
    # Description: helper routine for handling messages about no free leases
    # End-Doc
    sub handle_no_free_leases {
        my $sn   = shift;
        my $line = shift;

        if ( $sn eq "131.151.0.0/23" ) {

            # ignore known server subnets
            return;
        }

        if ( $line =~ /e1:6c:d6:ae:52:90/i || $line =~ /e9:eb:b3:a6:db:3c/ ) {

            # ignore spurious notices from MS iSCSI initiator startup
            return;
        }

        my $lastnotify = $last_notify_no_free{$sn};

        # Add some code here to figure out if the requesting mac addr is unknown, if so, can probably
        # skip the notification since it's likely for an unreg pool

        if ( time - $lastnotify > 10 * 60 ) {
            open( my $out, "|/usr/sbin/sendmail -t" );

            print $out "To: nneul\@neulinger.org\n";
            print $out "From: NetDB DHCP <netdb\@spirenteng.com>\n";
            print $out "Subject: DHCP leases exhausted ($sn)\n";
            print $out "\n";
            print $out "No available leases on subnet: $sn\n\n";

            print $out "Triggering log line: $line\n";
            close($out);

            $last_notify_no_free{$sn} = time;
        }
    }
}
