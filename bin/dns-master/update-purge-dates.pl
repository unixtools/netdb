#!/usr/bin/perl

# Begin-Doc
# Name: update-purge-dates.pl
# Type: script
# Description: update the expected purge date for each host entry
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
require NetMaint::DB;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::DBCache;

my $db    = new NetMaint::DB;
my $dhcp  = new NetMaint::DHCP;
my $dns   = new NetMaint::DNS;
my $force = 0;

my $cache = new NetMaint::DBCache;

#
# Only process hosts with null purge dates and/or old purge update dates
#
# 1) Never set purge_date before
# 2) purge_date was updated over 2 days ago
# 3) system expires in under 5 days - update every time, just in case it gets pushed off, unless it was supposed to expire over
#    5 days ago.
#
my $qry
    = "select host,type,purge_date,purge_date_updated from hosts where ( purge_date is null or mtime > purge_date_updated or "
    . "purge_date_updated < date_sub(now(),interval 2 day) or "
    . "(purge_date > date_sub(now(),interval 5 day) and purge_date < date_add(now(),interval 5 day)) ) "
    . "and type not in ('server','cname','network') "
    . "order by host";

if ( $ARGV[0] eq "-fast" ) {
    $qry
        = "select host,type,purge_date,purge_date_updated from hosts where (purge_date is null or mtime > purge_date_updated ) "
        . "and type not in ('server','cname','network') "
        . "order by host";
}
elsif ( $ARGV[0] ne "" ) {
    $qry
        = "select host,type,purge_date,purge_date_updated from hosts where host like "
        . $db->SQL_QuoteString( "%" . $ARGV[0] . "%" )
        . "and type not in ('server','cname','network') "
        . " order by host";
}

my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

#
# Open bound queries for the others so we'll be more efficient
#

while ( my ( $host, $type, $pd, $pdu ) = $db->SQL_FetchRow($cid) ) {
    print "$host: [$pd as of $pdu]\n";
    my $setcnt = 0;

    #
    # Get the last touch time for this host
    #
    my $qry2 = "select tstamp from last_touch_host where host=?";
    my $cid2 = $cache->open($qry2);
    $db->SQL_ExecQuery( $qry2, $host );
    my ($lth) = $db->SQL_FetchRow($cid2);

    print "  last_touch_host: $lth - ";
    $setcnt += &update_purge_date_auto( $host, $lth, $type );

    foreach my $ether ( $dhcp->GetEthers($host) ) {
        print "  last_touch_ether: $ether - ";
        my $qry2 = "select tstamp from last_touch_ether where ether=?";
        my $cid2 = $cache->open($qry2);
        $db->SQL_ExecQuery( $cid2, $ether );
        my ($lte) = $db->SQL_FetchRow($cid2);

        $setcnt += &update_purge_date_auto( $host, $lte, $type );
        if ( $db->SQL_RowCount() == 0 ) { print " (NC) "; }
        print "\n";
    }

    foreach my $iprec ( $dns->Get_Static_A_Records($host) ) {
        my $ip = $iprec->{address};

        print "  last_touch_ip: $ip  - ";

        my $qry2 = "select tstamp from last_touch_ip where ip=?";
        my $cid2 = $cache->open($qry2);
        $db->SQL_ExecQuery( $cid2, $ip );
        my ($lti) = $db->SQL_FetchRow($cid2);

        $setcnt += &update_purge_date_auto( $host, $lti, $type );
        if ( $db->SQL_RowCount() == 0 ) { print " (NC) "; }
        print "\n";
    }

    #
    # Get the cname target, if the target has a newer date, use it instead
    #
    foreach my $cname ( $dns->Get_CNAME_Records($host) ) {
        my $target = $cname->{address};
        print "  last_touch_host($target)  - ";

        if ($target) {
            my $qry2 = "select purge_date from hosts where host=?";
            my $cid2 = $cache->open($qry2);
            $db->SQL_ExecQuery( $cid2, $target );
            my ($ltt) = $db->SQL_FetchRow($cid2);

            print " $ltt ";
            $setcnt += &update_purge_date_exact( $host, $ltt );
            if ( $db->SQL_RowCount() == 0 ) { print " (NC) "; }
            print "\n";
        }
    }

    #
    # Last resort, if we still haven't set a purge date, set it to today+7
    #
    if ( $setcnt == 0 ) {
        print "  fallback to current date, but only if null - ";
        my $qry = "update hosts set purge_date_updated=now(),purge_date=date_add(now(),interval 7 day) "
            . "where host=? and purge_date is null";
        my $cid = $cache->open($qry);
        $db->SQL_ExecQuery( $cid, $host ) || $db->SQL_Error($qry);
        if ( $db->SQL_RowCount() == 0 ) { print " (NC) "; }
        print "\n";
    }
}

# Begin-Doc
# Name: update_purge_date_exact
# Description: Update based on the last update time
# End-Doc
sub update_purge_date_exact {
    my ( $host, $date ) = @_;
    my $qry;
    print "update for $host to $date\n";

    if ($date) {
        $qry = "update hosts set purge_date_updated=now(),purge_date=? where host=?";
        $qry .= " and (purge_date is null or ? > purge_date)";

        my $cid = $cache->open($qry);
        $db->SQL_ExecQuery( $cid, $date, $host, $date )
            || $db->SQL_Error($qry);

        return 1;
    }
    return 0;
}

# Begin-Doc
# Name: update_purge_date_auto
# Description: Update based on the last update time
# End-Doc
sub update_purge_date_auto {
    my ( $host, $date ) = @_;
    my $qry;
    my $days = 180;

    if ($date) {
        print "new date: $date + ${days} ";

        $qry = "update hosts set purge_date_updated=now(),purge_date=date_add(?,interval ? day) where host=?";
        $qry .= " and (purge_date is null or date_add(?,interval ? day) > purge_date)";

        my $cid = $cache->open($qry);
        $db->SQL_ExecQuery( $cid, $date, $days, $host, $date, $days )
            || $db->SQL_Error($qry);

        return 1;
    }
    return 0;
}

