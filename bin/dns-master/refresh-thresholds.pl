#!/usr/bin/perl

# Begin-Doc
# Name: refresh-thresholds.pl
# Type: script
# Description: update dns zone thresholds
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use UMR::SysProg::SetUID;

use NetMaint::DB;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";

#
# Refresh thresholds based on last active file size/line counts
#

# Useful interactive query
# select zone,thresh_size,last_size,round(last_size * .66),thresh_lines,last_lines,round(last_lines * .66) from dns_soa order by zone;

my $qry
    = "update dns_soa set thresh_size=round(last_size * .66),thresh_lines=round(last_lines * .66) where last_lines>thresh_lines and last_size>thresh_size";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;

