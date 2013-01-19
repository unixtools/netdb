#!/usr/bin/perl

# Begin-Doc
# Name: clean-arpscan.pl
# Type: script
# Description: mark out-of-date arp data in arpscan table
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::OracleObject;

use lib "/local/netdb/libs";
use NetMaint::DB;

my $db = new NetMaint::DB() || die "failed to open db!";

# If it's over 2 hours old, it's out of date
my $qry = "update arpscan set latest=0 where latest=1 and tstamp < date_sub(now(),interval 2 hour)";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;
