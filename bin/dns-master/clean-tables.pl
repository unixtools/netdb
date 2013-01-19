#!/usr/bin/perl

# Begin-Doc
# Name: clean-tables.pl
# Type: script
# Description: clean/purge data from tables as needed
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::OracleObject;
use UMR::SysProg::SetUID;

use lib "/local/netdb/libs";
use NetMaint::DB;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";

my $chunk = 10000;

#
# Retention needs to be larger than the longest lease time (8 days)
#

&repeat_till_done( "delete from dhcp_curleases where tstamp<date_sub(now(),interval 14 day) limit ?", $chunk );

&repeat_till_done( "delete from dns_a where name like 'dyn-%' and mtime<date_sub(now(),interval 14 day) limit ?",
    $chunk );

&repeat_till_done( "delete from dhcp_acklog where tstamp<date_sub(now(),interval 14 day) limit ?", $chunk );

&repeat_till_done( "delete from arpscan where tstamp<date_sub(now(),interval 14 day) limit ?", $chunk );

&repeat_till_done( "delete from log where tstamp<date_sub(now(),interval 120 day) limit ?", $chunk );

# Begin-Doc
# Name: repeat_till_done
# Description: repeatedly runs a sql query until number of rows affected is zero
# Syntax: &repeat_till_done($qry, @args);
# End-Doc
sub repeat_till_done {
    my $qry   = shift;
    my $chunk = shift;

    my $cnt;
    while ( !defined($cnt) || $cnt > 0 ) {
        print "+ $qry\n";
        $db->SQL_ExecQuery( $qry, $chunk ) || $db->SQL_Error($qry) && die;
        $cnt = $db->SQL_RowCount();
        print "  deleted $cnt rows.\n";
        last if ( $cnt < $chunk );
        sleep 2;
    }
}

