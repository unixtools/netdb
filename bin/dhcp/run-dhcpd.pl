#!/usr/bin/perl

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::SetUID;

$| = 1;
umask(022);

# Fork
if (1) {
    if ( fork() ) {
        exit;
    }
}

#
# Terminate any existing processes
#
print "Scanning for existing processes.\n";
open( my $psfh, "ps auxwww|" );
while ( chomp( my $line = <$psfh> ) ) {
    my @tmp = split( ' ', $line );

    if ( $line =~ /dhcpd.*dhcpd.conf/ && $tmp[1] != $$ ) {
        print "Killing: $line\n";
        kill 15, $tmp[1];
        select undef, undef, undef, .25;
        kill 9, $tmp[1];
    }
}
close($psfh);
print "Done.\n";

# Delay for a moment
sleep(1);

#
# Start dhcpd before we change uid
#
my $childpid = open( my $childfh, "-|" );
if ( !defined($childpid) ) {
    print "Failed to open dhcpd pipe.\n";
    exit;
}
elsif ( !$childpid ) {
    close(STDIN);
    open( STDERR, ">&STDOUT" );

    my @interfaces;
    if ( $ENV{NETDB_DHCP_INTERFACES} ) {
        @interfaces = split( /[\,\;:\s]+/, $ENV{NETDB_DHCP_INTERFACES} );
    }

    $ENV{MALLOC_CHECK_} = "0";
    exec(
        "/local/dhcp/sbin/dhcpd", "-d", "-cf", "/local/dhcp-root/etc/dhcpd.conf",
        "-lf", "/local/dhcp-root/etc/dhcpd.leases",
        "-pf", "/local/dhcp-root/etc/dhcpd.pid", @interfaces
    );
    exit(0);
}

#
# Close output
#
close(STDIN);
close(STDOUT);
close(STDERR);

# Base log directory
my $base    = "/local/dhcp-root/netdb-logs";
my $baselog = "/local/dhcp-root/netdb-logs/log.current";

# Change ownership of all log files in case any owned by root, and switch to netdb userid
mkdir( $base, 0755 );
system("chown -R netdb:netdb $base");

&SetUID("netdb");

$| = 1;

# Read forever
my $lastswitch = time;
while ( my $line = <$childfh> ) {
    print "opening $baselog\n";
    open( my $logfh, ">>$baselog" ) || print "failed to open log chunk $!\n";
    print $logfh time, ": ", $line;
    close($logfh);

    # Rotate every 10 seconds
    if ( time - $lastswitch > 10 ) {
        if ( -e $baselog ) {
            print "Switching file.\n";
            my $newlog = sprintf( "$base/log.%10d", time );
            rename( $baselog, $newlog );
        }
        $lastswitch = time;
    }
}
print "Terminating run-dhcpd.\n";
