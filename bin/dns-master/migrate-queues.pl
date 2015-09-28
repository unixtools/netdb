#!/usr/bin/perl

# Begin-Doc
# Name: migrate-queues.pl
# Type: script
# Description: process the dhcp inbound activity logs and populate tables, avoids locking primary tables
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::SetUID;
use Getopt::Long;
require NetMaint::DB;

use Time::HiRes qw(time);

&SetUID("netdb");

my $help  = 0;
my $trace = 0;
my $once  = 0;
my $debug = 0;
my $res   = GetOptions(
    "help"   => \$help,
    "trace+" => \$trace,
    "debug+" => \$debug,
    "once"   => \$once,
);

if ( !$res || $help ) {
    print "Usage: $0 [--help] [--debug] [--trace] [--once]\n";
    exit;
}

open( STDERR, ">&STDOUT" );

# Should never go multiple minutes stuck in a call
alarm(600);

my $records       = 0;
my $total_records = 0;
my $db;
my $lastopen;
my $delays = 0;

my %fields = ();

while (1) {
    $records = 0;

    my $table = "dhcp_acklog";
    my $queue = "dhcp_acklog_queue";

    if ( time - $lastopen > 600 ) {
        if ( $lastopen != 0 ) {
            print "Closing database connection.\n";
            &NetMaint::DB::CloseDB();
        }

        $db       = new NetMaint::DB;
        $lastopen = time;

        # Generate field list minus the ID field
        my $qry  = "select * from $queue where 1=0";
        my $cid  = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
        my %info = $db->SQL_ColumnInfo($cid);
        my @cols = ();
        foreach my $col ( @{ $info{colnames} } ) {
            $col = lc $col;
            next if ( $col eq "id" );
            push( @cols, $col );
        }
        $db->SQL_CloseQuery($cid);
        $fields{$queue} = join( ",", @cols );
    }

    my $chunk = 100;

    my @ids    = ();
    my $selqry = "select id from $queue order by id limit $chunk";
    my $cid    = $db->SQL_OpenQuery($selqry) || $db->SQL_Error($selqry);
    while ( my ($id) = $db->SQL_FetchRow($cid) ) {
        $records++;
        $total_records++;
        push( @ids, $id );

        if ( $total_records % 1000 == 0 ) {
            print "[$total_records] records migrated from $queue to $table ($delays delays)\n";
        }
    }
    $db->SQL_CloseQuery($cid);

    if (@ids) {
        my $fields = $fields{$queue};
        my $idstring = join( ",", @ids );

        my $insqry = "replace into $table($fields) select $fields from $queue where " . "id in ($idstring)";
        $db->SQL_ExecQuery($insqry) || $db->SQL_Error($insqry) && die;

        my $delqry = "delete from $queue where id in ($idstring)";
        $db->SQL_ExecQuery($delqry) || $db->SQL_Error($delqry) && die;
    }

    if ($once) {
        print "exiting, single run was requested.\n";
        exit;
    }

    if ( $records < $chunk ) {
        $debug && print "delaying, fewer records received than chunk size.\n";
        $delays++;
        sleep 5;
    }
}

