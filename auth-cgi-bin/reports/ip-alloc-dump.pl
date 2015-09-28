#!/usr/bin/perl

# Begin-Doc
# Name: subnet-ip-alloc.pl
# Type: script
# Description: Report on ip allocation by subnet
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Util;
require NetMaint::DNS;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType("text/plain");

my $db  = new NetMaint::DB;
my $log = new NetMaint::Logging;

$log->Log();

my $qry = "select subnet, ip, type from ip_alloc order by ip";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);

while ( my ( $subnet, $ip, $alloc ) = $db->SQL_FetchRow($cid) ) {
    print join( "\t", $subnet, $ip, $alloc ), "\n";
}
