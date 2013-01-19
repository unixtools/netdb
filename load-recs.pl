#!/usr/bin/perl

exit 0;

use lib "/local/perllib/libs";
use Local::MySQLObject;
use Local::SetUID;
use Net::DNS;

&SetUID("netdb");

my $db = new Local::MySQLObject;
$db->SQL_OpenDatabase("netdb") || die;

my $res = Net::DNS::Resolver->new || die;
$res->debug(0);
$res->nameservers("netmgr.spirenteng.com");

foreach my $zone (
    qw(
    100.155.10.in-addr.arpa
    0.155.10.in-addr.arpa
    2.155.10.in-addr.arpa
    50.71.10.in-addr.arpa
    6.41.10.in-addr.arpa
    7.41.10.in-addr.arpa
    fanfaregroup.com
    fanfaresoftware.com
    fnfr.com
    fnfr.net
    spirenteng.com
    )
    )
{
    print "$zone:\n";
    my @recs = $res->axfr($zone);
    print " rec count: ", scalar(@recs), "\n";

    foreach my $rr (@recs) {

        #print " got rr $rr\n";
        my $name      = lc $rr->name;
        my $netdbtype = "device";
        if ( $name =~ /fc-/ ) {
            $netdbtype = "server";
        }

        if ( $rr->type eq "A" ) {
            my $addr = $rr->address;

            my $qry = "replace into hosts(host,domain,type,owner,mtime,ctime) values (?,?,?,'netdb',now(),now())";
            $db->SQL_ExecQuery( $qry, $name, $zone, $netdbtype ) || $db->SQL_Error($qry);

            my $qry = "replace into dns_a(zone,name,address,mtime,ctime) values (?,?,?,now(),now())";
            $db->SQL_ExecQuery( $qry, $zone, $name, $addr ) || $db->SQL_Error($qry);
        }
        elsif ( $rr->type eq "CNAME" ) {
            my $cname = lc $rr->cname;
            $netdbtype = "cname";

            my $qry = "replace into hosts(host,domain,type,owner,mtime,ctime) values (?,?,?,'netdb',now(),now())";
            $db->SQL_ExecQuery( $qry, $name, $zone, $netdbtype ) || $db->SQL_Error($qry);

            my $qry = "replace into dns_cname(zone,name,address,mtime,ctime) values (?,?,?,now(),now())";
            $db->SQL_ExecQuery( $qry, $zone, $name, $cname ) || $db->SQL_Error($qry);
        }
        elsif ( $rr->type eq "MX" ) {
            my $priority = $rr->preference;
            my $addr     = $rr->exchange;

            my $qry = "replace into dns_mx(zone,name,priority,address,mtime,ctime) values (?,?,?,?,now(),now())";
            $db->SQL_ExecQuery( $qry, $zone, $name, $priority, $addr ) || $db->SQL_Error($qry);
        }
        elsif ( $rr->type eq "NS" ) {
            my $addr     = $rr->nsdname;

            my $qry = "replace into dns_ns(zone,name,address,mtime,ctime) values (?,?,?,now(),now())";
            $db->SQL_ExecQuery( $qry, $zone, $name, $addr ) || $db->SQL_Error($qry);
        }
        elsif ( $rr->type eq "PTR" ) {
            my $addr     = $rr->ptrdname;

            my $qry = "replace into dns_ptr(zone,name,address,mtime,ctime) values (?,?,?,now(),now())";
            $db->SQL_ExecQuery( $qry, $zone, $name, $addr ) || $db->SQL_Error($qry);
        }
        elsif ( $rr->type eq "SRV" ) {
            my $priority = $rr->priority;
            my $weight   = $rr->weight;
            my $port     = $rr->port;
            my $addr     = $rr->target;

            my $qry = "replace into dns_srv(zone,name,priority,weight,port,address,mtime,ctime) values (?,?,?,?,?,?,now(),now())";
            $db->SQL_ExecQuery( $qry, $zone, $name, $priority, $weight, $port, $addr ) || $db->SQL_Error($qry);
        }
        elsif ( $rr->type eq "SOA" ) {
            # skip
        }
        else {
            print "Unable to handle record $name (", $rr->type, ")\n";
        }
    }
}
