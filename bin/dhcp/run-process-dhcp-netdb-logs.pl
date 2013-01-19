#!/usr/bin/perl

# Begin-Doc
# Name: run-process-dhcp-netdb-logs.pl
# Type: script
# Description: start or restart the netdb log processing script
# End-Doc

use strict;

close(STDIN);
close(STDOUT);
close(STDERR);

if (fork) {
    exit;
}

open( STDOUT, "|/usr/bin/logger -t dhcp-logs" );
open( STDERR, ">&STDOUT" );
$| = 1;

while (1) {
    system("/local/netdb/bin/dhcp/process-dhcp-netdb-logs.pl");
    sleep 5;
}
