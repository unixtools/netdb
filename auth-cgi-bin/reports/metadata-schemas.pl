#!/usr/bin/perl

# Begin-Doc
# Name: metadata-schemas.pl
# Type: script
# Description: Schema listing for host metadata
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::DB;
require NetMaint::Hosts;
require NetMaint::Logging;
use JSON;

use Local::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Metadata Schema List" );

my $db = new NetMaint::DB;

$html->StartMailWrapper("Metadata Schema List");

my $qry
    = "select field, label, description, viewpriv, editpriv, jsonschema, ctime, mtime from metadata_fields order by field";
my $cid = $db->SQL_OpenQuery($qry) || $html->ErrorExitSQL( "failed qry", $db );
my $json = new JSON;

$html->StartBlockTable("Metadata Schemas");
$html->StartInnerTable();

while ( my ( $field, $label, $desc, $view, $edit, $schema, $ctime, $mtime ) = $db->SQL_FetchRow($cid) ) {
    $html->StartInnerHeaderRow();
    print "<td align=center><b>$field - $label</b></td>\n";
    $html->EndInnerHeaderRow();
    $html->StartInnerRow();
    print "<td>\n";
    print "<pre>\n";

    my $sdata;
    eval { $sdata = decode_json($schema); };
    if ($sdata) {
        print $json->pretty->encode($sdata), "\n";
    }
    else {
        print "<b>Failed to parse:</b>\n";
        print $schema, "\n";
    }
    print "</pre>\n";
    print "</td>\n";
    $html->EndInnerRow();
}

$db->SQL_CloseQuery($cid);

$html->EndInnerTable();
$html->EndBlockTable();

$html->EndMailWrapper();

$html->PageFooter();

