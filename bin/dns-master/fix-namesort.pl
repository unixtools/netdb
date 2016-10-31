#!/usr/bin/perl

# Begin-Doc
# Name: fix-namesort.pl
# Type: script
# Description: update any missing namesort entries in dns_ptr table
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use NetMaint::Config;
require NetMaint::DB;
require NetMaint::DNS;

my $dns = new NetMaint::DNS;
my $db  = new NetMaint::DB;

my $qry = "select name from dns_ptr";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ($arpa) = $db->SQL_FetchRow($cid) ) {
    print $arpa, "\n";
    print $dns->UpdateNamesort($arpa);
}
