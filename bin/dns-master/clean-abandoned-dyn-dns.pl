#!/usr/bin/perl

# Begin-Doc
# Name: clean-abandoned-dyn-dns.pl
# Type: script
# Description: remove any old/lost dynamic dns registrations
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use NetMaint::DB;

my $db = new NetMaint::DB() || die "failed to open db!";

# if the dyn dns reg is over x days old, and we haven't seen or touched
# that host or ip in the past x days or seen it on the network, then
# clear that dns registration.

# This is all the more relevant since dynamic regs are only assigned via DHCP
# and they are invalid if not renewed after about 2 hours, so this should
# really be a lot shorter than x days.

#
# Retention needs to be higher than max lease time
#

my $qry
    = "delete from dns_a where dynamic=1 and mtime < date_sub(now(),interval 14 day) and "
    . "name not in (select host from last_touch_host where tstamp > date_sub(now(),interval 14 day)) and "
    . "address not in (select ip from last_touch_ip where tstamp > date_sub(now(),interval 14 day))";

$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;

#
# Not as precise a check here, but still safe
#
my $qry = "delete from dns_ptr where dynamic=1 and mtime < date_sub(now(),interval 14 day)";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;

#
# Clean up dynamics that are registered, but no longer valid leases
#
my $qry
    = "delete from dns_a where dynamic=1 and mtime < date_sub(now(),interval 14 day) and "
    . " address not in (select ip from dhcp_curleases) and address in "
    . " (select ip from ip_alloc where type='dynamic')";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;

my $qry = "delete from dns_ptr where address like '%.spirenteng.com' and "
    . "address not in (select name from dns_a) and mtime < date_sub(now(),interval 14 day)";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry) && die;
