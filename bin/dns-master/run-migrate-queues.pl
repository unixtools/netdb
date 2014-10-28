#!/usr/bin/perl

# Begin-Doc
# Name: run-migrate-queues.pl
# Type: script
# Description: start or restart the netdb queue table processing script
# End-Doc

use strict;

close(STDIN);
close(STDOUT);
close(STDERR);

if (fork) {
    exit;
}

open( STDOUT, "|/usr/bin/logger -t migrate-queues" );
open( STDERR, ">&STDOUT" );
$| = 1;

while (1) {
    system("/local/netdb/bin/dns-master/migrate-queues.pl");
    sleep 5;
}
