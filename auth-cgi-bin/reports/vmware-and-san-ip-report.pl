#!/usr/bin/perl

# Begin-Doc
# Name: vmware-and-san-ip-report.pl
# Type: script
# Description: IP Address report for vmware and san hosts
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
$html->PageHeader( title => "View ARP History for Ethernet Address" );

my $log = new NetMaint::Logging;
my $db  = new NetMaint::DB;

$log->Log();

my $info = {};
my %cols;

my $qry = "select ip,host from ip_alloc where host like 'vm-%' 
union
select address,name from dns_a where name like 'vm-%' 
";
my $cid = $db->SQL_OpenQuery($qry) || $html->ErrorExitSQL( $db, "select all hosts/ips" );

while ( my ( $ip, $host ) = $db->SQL_FetchRow($cid) ) {
    my $type = "other";

    my $shost = $host;
    $shost =~ s|\..*||go;

    if ( $host =~ /^(vm-[a-z]+\d+).srv/ ) {
        $type  = "host";
        $shost = $1;
    }
    elsif ( $host =~ /^(vm-[a-z]+\d+)-((iscsi|vmotion|ipmi)\d*)\./ ) {
        $type  = $2;
        $shost = $1;
    }
    else {
        print "<br>Can't parse ($host)\n";
    }

    $info->{$shost}->{$type}->{$ip} = $host;
    $cols{$type} = 1;
}

my @cols = sort( keys(%cols) );

$html->StartMailWrapper("VMWare and SAN IP Report");
$html->StartBlockTable("VMWare and SAN IP Report");
$html->StartInnerTable( "Host", @cols );

foreach my $host ( sort( keys(%$info) ) ) {
    $html->StartInnerRow();

    print "<td>$host</td>\n";

    foreach my $col (@cols) {
        print "<td>\n";
        my @addr = sort( keys( %{ $info->{$host}->{$col} } ) );
        print join( "<br>", @addr );

        if ( $#addr < 0 ) {
            if ( $col =~ /iscsi/ ) {
                print
                    "<a href=\"/auth-cgi-bin/cgiwrap/netdb/create-host.pl?mode=create&nametype=customname&type=server&hostname="
                    . "${host}-${col}&domain=srv.mst.edu&owner=namesrv&ether=\">Create</a> - ";
                print "<a href=\"/auth-cgi-bin/cgiwrap/netdb/edit-host.pl?mode=autoaddstatic&host="
                    . "${host}-${col}.srv.mst.edu&direction=up&subnet=10.2.16.0%2F22\">Allocate</a>";
            }
        }
        print "</td>\n";
    }

    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();

