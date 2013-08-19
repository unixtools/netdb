#!/usr/bin/perl

# Begin-Doc
# Name: run-watch-arp.pl
# Type: script
# Description: start or restart the continuous arp watching of subnets
# End-Doc

use strict;
use Sys::Hostname;

close(STDIN);
close(STDOUT);
close(STDERR);

if (fork) {
    exit;
}

open( STDOUT, "|/usr/bin/logger -t watch-arp" );
open( STDERR, ">&STDOUT" );
$| = 1;

while (1) {
    system("/local/netdb/bin/dhcp/watch-arp.pl");
    sleep 5;
}
