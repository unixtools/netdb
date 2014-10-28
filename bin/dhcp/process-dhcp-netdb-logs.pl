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
use Getopt::Long;
use NetMaint::Config;
require NetMaint::Leases;
require NetMaint::DNS;
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::Access;
require NetMaint::Network;
use POSIX ":sys_wait_h";

use Time::HiRes qw(time);
use Sys::Hostname;

&SetUID("netdb");

my $base = "/local/dhcp-root/netdb-logs";

my $help    = 0;
my $trace   = 0;
my $once    = 0;
my $onefile = 0;
my $debug   = 0;
my $res     = GetOptions(
    "help"    => \$help,
    "trace+"  => \$trace,
    "debug+"  => \$debug,
    "once"    => \$once,
    "onefile" => \$onefile,
);

if ( !$res || $help ) {
    print "Usage: $0 [--help] [--debug] [--trace] [--once] [--onefile]\n";
    exit;
}

my $server = hostname;
$server =~ s|\..*||gio;

open( STDERR, ">&STDOUT" );

# Should never go more than $max_idle minutes stuck in a call
my $max_idle = 30 * 60;

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
my $net;

my $last_backlog;
my $last_backlog_notify;

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
        $net    = new NetMaint::Network;

        $lastopen = time;
    }

    # get list of files in log dir
    opendir( my $logdir, $base );
    my $filecnt = 0;
    foreach my $file ( sort( readdir($logdir) ) ) {
        next if ( $file !~ /^log\.\d+$/o );

        my @stat = stat("$base/$file");
        my $age  = time - $stat[9];
        if ( ( $age > 90 * 60 ) && $stat[9] ) {
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

            if ( !$last_backlog || time - $last_backlog > 30 ) {
                my $tstamp = $line;
                $tstamp =~ s/:.*//go;
                $tstamp = int($tstamp);

                my $secs = int( time - $tstamp );
                print "Current Log Processing Backlog: $secs seconds \n";

                if ( $secs > 300 ) {
                    if ( time - $last_backlog_notify > 30 * 60 * 60 ) {
                        print "Sending backlog notice.\n";

                        open( my $out, "|/usr/sbin/sendmail -t" );

                        print $out "To: $NETDB_DEFAULT_NOTIFY\n";
                        print $out "From: NetDB DHCP <$NETDB_MAIL_FROM>\n";
                        print $out "Subject: NetDB DHCP Excessive Backlog\n";
                        print $out "\n";
                        print $out "Notice will be sent at most once every 30 minutes until condition clears.\n";
                        print $out "Current Backlog: $secs seconds\n";
                        print $out "\n";
                        print $out `find /local/dhcp-root/netdb-logs -ls`;
                        close($out);

                        $last_backlog_notify = time;
                    }
                    else {
                        print "Skipping backlog notice.\n";
                    }
                }

                $last_backlog = time;
            }

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

                # these seem to be generated solely in response to DHCPINFORM, which should not trigger
                # lease behavior
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
            elsif ( $line =~ /^(\d+): DHCPNAK on ([\d\.]+) to ([A-Fa-f0-9:]+) via (.*)/o ) {
                &handle_error( $1, $3, $2, $4 );
            }
            elsif ( $line =~ /^(\d+): ICMP Echo reply while lease ([\d\.]+) valid/o ) {
                &handle_error( $1, "", $2, "" );
            }
            elsif ( $line =~ /^(\d+): Abandoning IP address ([\d\.]+):/o ) {
                &handle_error( $1, "", $2, "" );
            }
            elsif ( $line =~ /^(\d+): DHCPDECLINE of ([\d\.]+) from ([A-Fa-f0-9:]+) via (.*)/o ) {
                &handle_error( $1, $3, $2, $4 );
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

        if ($onefile) {
            print "exiting, single file was requested.\n";
            exit;
        }
    }
    closedir($logdir);

    if ( $filecnt == 0 ) {
        sleep 2;
    }

    if ($once) {
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

# Begin-Doc
# Name: handle_error
# Description: helper routine for handling error notices
# End-Doc
sub handle_error {
    my ( $ts, $ether, $ip, $gw ) = @_;

    $debug && print "got error for $ether or $ip via $gw\n";

    $trace && print "REL[";
    $leases->RecordErrorLease(
        ip      => $ip,
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

        # ignore known server subnets
        if ( $sn eq "131.151.0.0/23" ) {
            return;
        }

        # ignore spurious notices from MS iSCSI initiator startup
        if ( $line =~ /e1:6c:d6:ae:52:90/i || $line =~ /e9:eb:b3:a6:db:3c/ ) {
            return;
        }

        my $lastnotify = $last_notify_no_free{$sn};

        my $target = $NETDB_DEFAULT_NOTIFY;

        my $hname = "";
        my $mac   = "";
        if ( $line =~ /(..:..:..:..:..:..)/ ) {
            $mac = $1;
        }
        if ($mac) {
            $hname = $dhcp->SearchByEtherExact($mac);
        }
        my $sninfo  = $net->GetSubnets();
        my $snlabel = $sninfo->{$sn}->{description};

        if ( $sn =~ /^10\.155/ || $snlabel =~ /Sunnyvale/io ) {
            $target .= ",angel.comonfort\@spirent.com";
        }

        # Add some code here to figure out if the requesting mac addr is unknown, if so, can probably
        # skip the notification since it's likely for an unreg pool
        my $msg_delta = 10 * 60;

        if ( $target && time - $lastnotify > $msg_delta ) {
            my %type_counts = $net->GetAllocationTypeCounts($sn);

            print "Sending notice for $snlabel to $target for host ($hname) / addr ($mac).\n";

            open( my $out, "|/usr/sbin/sendmail -t" );

            print $out "To: $target\n";
            print $out "From: NetDB DHCP <$NETDB_MAIL_FROM>\n";
            print $out "Subject: DHCP leases exhausted ($sn)\n";

            print $out "\n";

            print $out "Triggering log line: $line\n\n";

            print $out "Notification Target: $target\n";
            print $out "Triggering Address: $mac\n";
            print $out "Subnet: $sn\n";
            print $out "Subnet Template: ", $sninfo->{$sn}->{template}, "\n";
            print $out "Subnet VLAN: ",     $sninfo->{$sn}->{vlan},     "\n";
            print $out "Description: $snlabel\n\n";

            if ( $hname ne "" ) {
                print $out "Host ($hname) is known. Exhaustion likely in normal pool.\n";
                if ( $type_counts{dynamic} == 0 ) {
                    print $out "No dynamic addresses on subnet: $sn\n";
                }
            }
            elsif ( $type_counts{dynamic} == 0 && $type_counts{unreg} == 0 ) {
                print $out "Host is not known and no dynamic addresses on subnet.\n";
                print $out "This is likely an infrastructure subnet.\n";
            }
            else {
                print $out "Host is not known. Exhaustion is likely in unreg pool.\n";
                if ( $type_counts{unreg} == 0 ) {
                    print $out "No unreg addresses on subnet: $sn\n";
                }
            }

            print $out "\n";
            print $out "IP Address Allocation on Subnet: (not usage)\n";
            foreach my $type ( sort( keys(%type_counts) ) ) {
                print $out "  $type: ", $type_counts{$type}, "\n";
            }

            close($out);

            print "Done sending notice for $snlabel to $target for host ($hname) / addr ($mac).\n";

            $last_notify_no_free{$sn} = time;
        }
    }
}
