#!/usr/bin/perl

# Begin-Doc
# Name: cnames-by-target.pl
# Type: script
# Description: Report on cnames by target
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::DB;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "CNames by Target" );

my $db = new NetMaint::DB;

my $qry = "select h.host,c.address from hosts h
    left outer join dns_cname c on (h.host=c.name)
    where (h.type is null or h.type='cname')
    order by c.address,h.host";

my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

$html->StartMailWrapper("CNames by Target");
$html->StartBlockTable("CNames by Target");
$html->StartInnerTable( "Target", "Host" );

my $lt;
while ( my ( $host, $target ) = $db->SQL_FetchRow($cid) ) {
    if ( $target ne $lt && $lt ne "" ) {
        $html->StartInnerHeaderRow();
        print "<td colspan=2>&nbsp;</td>\n";
        $html->EndInnerHeaderRow();
    }
    $lt = $target;

    $html->StartInnerRow();
    print "<td align=left>$target</td><td>$host</td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();
