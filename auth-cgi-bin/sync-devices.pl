#!/usr/bin/perl

# Begin-Doc
# Name: sync-devices.pl
# Type: script
# Description: trigger a sync of network devices to mac block table
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use UMR::PrivSys;
use UMR::AuthSrv;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Register;
require NetMaint::Logging;

use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Sync Network Device Config" );
my $util = new NetMaint::Util;
my $log  = new NetMaint::Logging;

$html->PageHeader();
$html->RequirePriv("sysprog:netdb:syncnet");

$log->Log();

&AuthSrv_Authenticate( keep_ccache => 1 );

print "<h3>Starting at: ", scalar(localtime), "</h3>\n";

print "<pre><p align=left>\n";

# Purge known hosts in case it changes
unlink("/local/netdb/.ssh/known_hosts");

system( "/usr/bin/ssh", "netdb\@netstat.srv.mst.edu", "/local/netdb/bin/netstat/update-mac-block-table.pl" );
system( "/usr/bin/ssh", "netdb\@netstat.srv.mst.edu", "/local/netdb/bin/netstat/update-switch-mac-block-list.pl" );

print "</p></pre>\n";

print "<h3>Finished at: ", scalar(localtime), "</h3>\n";

&AuthSrv_Unauthenticate();
$html->PageFooter();
