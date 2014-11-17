#!/usr/bin/perl

# Begin-Doc
# Name: ajax-metadata-update.pl
# Type: script
# Description: ajax callback for updating metadata from editor
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use UMR::PrivSys;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Logging;
use JSON;

&HTMLGetRequest();
&HTMLContentType("application/json");

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs('public') );

my $hosts  = new NetMaint::Hosts;
my $util   = new NetMaint::Util;
my $log    = new NetMaint::Logging;
my $access = new NetMaint::Access;

my $field = $rqpairs{field};
my $value = $rqpairs{value};
my $host  = $rqpairs{host};

$log->Log();

# get the field info, host perms, etc.

# decide what to do with the field and update db/etc.

print encode_json(
    {   "status" => "ok",
        "data"   => { "field" => $field, value => $value, host => $host }
    }
);

1;
