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

my $host  = $rqpairs{host};
my $field = $rqpairs{field};
my $value = $rqpairs{value};

$log->Log();

if ( !$host || !$field || !$value ) {
    &fail("Must specify host, value, and field.");
}

my $info = $hosts->GetHostInfo($host);
if ( !$info ) {
    &fail("Invalid host.");
}

my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );

if ( !$edit_ok ) {
    &fail("Host edit permission denied.");
}

# if we got this far, just update
my $db = new NetMaint::DB || &fail("failed to connect to db");

# get the field info, host perms, etc.
my $qry = "select field,editpriv from metadata_fields where field=?";
my ( $qf, $editpriv ) = $db->SQL_DoQuery( $qry, $field );
if ( $qf ne $field ) {
    &fail("Couldn't locate field info");
}

if ( $editpriv && !$privs{$editpriv} ) {
    &fail("Permission denied updating field.");
}

my $res = $hosts->SetMetadataField($host, $field, $value);
if ( $res )
{
    &fail($res);
}

print encode_json(
    {   "status" => "ok",
        "data"   => { "field" => $field, value => $value, host => $host }
    }
);

# Begin-Doc
# Name: fail
# Description: returns json failure message
# Syntax: &fail($msg);
# End-Doc

sub fail {
    my $msg = shift;
    print encode_json(
        {   "status"  => "fail",
            "message" => $msg
        }
    );
    exit(0);
}

1;
