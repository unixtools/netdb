#!/usr/bin/perl

# Begin-Doc
# Name: build-tftp.pl
# Type: script
# Description: update the tftp configs for printer boot files
# End-Doc

$| = 1;

#
# DO NOT MAKE THIS SETUID - IT SHOULD RUN AS ROOT, NOT AS NETDB
#

close(STDIN);
open( STDIN, "</dev/null" );
print "Updating tftp boot area (non-printer):\n";
system( "/usr/bin/svn", "update", "/local/tftp" );
