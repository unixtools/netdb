#!/usr/bin/perl

# Begin-Doc
# Name: edit-host-metadata.pl
# Type: script
# Description: edit host metadata by single host, detailed
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
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Edit Host Metadata" );

my %privs = ( &PrivSys_FetchPrivs( $ENV{REMOTE_USER} ), &PrivSys_FetchPrivs('public') );

$html->PageHeader();

my $hosts  = new NetMaint::Hosts;
my $util   = new NetMaint::Util;
my $log    = new NetMaint::Logging;
my $access = new NetMaint::Access;

my $mode = lc $rqpairs{mode} || "searchform";
my $host = lc $rqpairs{host};

$log->Log();

if ( $mode eq "searchform" ) {
    &DisplaySearchForms();
}
elsif ( $mode eq "search" ) {
    my @hosts = $hosts->SearchByName( $rqpairs{host}, 1000 );

    if ( $#hosts == 0 ) {

        # If we have only one host in the search results, try to immediately
        # refresh to the view page for that host.
        my $host = $hosts[0];

        print "<meta http-equiv=\"Refresh\" content=\"0; URL=";
        print "edit-host-metadata.pl?mode=view&host=" . $host . "\">\n";

        print "Found single match for <tt>$host</tt>. Refreshing to ";
        print "<a href=\"?mode=view&host=$host\">edit</a> page.\n";
    }
    elsif ( $#hosts < 0 ) {
        print "<h3>No matching hosts.</h3>\n";
        &DisplaySearchForms();
    }
    else {
        &HTMLStartForm( "edit-host-metadata.pl", "GET" );
        &HTMLHidden( "mode", "view" );
        print "Matching hosts: ";
        &HTMLStartSelect( "host", 1 );
        foreach my $hn (@hosts) {
            print "<option>$hn\n";
        }
        &HTMLEndSelect();
        &HTMLSubmit("Edit Host");
        &HTMLEndForm();
    }
}
elsif ( $mode eq "view" )    # display the host, exact match only
{
    my $info = $hosts->GetHostInfo($host);
    if ($info) {

        # search by host name passed, if found, display edit form for that host
        print "<p/><hr/><p/>\n";
        &DisplaySearchForms();
        print "<p/><hr/><p/>\n";

        &DisplayHost($host);
    }
    else {
        print "<h3>Unable to find host <tt>", $html->Encode($host), "</tt>.</h3><p/>\n";
        &DisplaySearchForms();
    }
}

# Begin-Doc
# Name: DisplayHost
# Description: displays host with various forms and links for performing edit operations
# Syntax: &DisplayHost($host);
# End-Doc
sub DisplayHost {
    my $host = shift;
    my $info;
    my $db = new NetMaint::DB;

    print <<AUTOSUGGEST;
<link rel="stylesheet" href="/~netdb/js/jquery-ui-themes/themes/smoothness/jquery-ui.css" />
<link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/font-awesome/4.0.3/css/font-awesome.css" />

<script type="text/javascript" src="/~netdb/js/jquery.min.js"></script>
<script type="text/javascript" src="/~netdb/js/jquery-ui/jquery-ui.min.js"></script>
<script type="text/javascript" src="/~netdb/js/json-editor/dist/jsoneditor.min.js"></script>
<script type="text/javascript">
JSONEditor.defaults.options.iconlib = 'fontawesome4';
</script>
AUTOSUGGEST

    # Need access check

    my $info = $hosts->GetHostInfo($host);
    if ( !$info ) {
        $html->ErrorExit( "Host (", $html->Encode($host), ") not found." );
    }

    print "<a href=\"?mode=view&host=$host\">Refresh Display</a><p/>\n";

    print "<p/>\n";
    $html->Display_HostInfo($info);

    my $mdinfo = $hosts->GetHostMetadata($host);

    my $qry = "select field,type,jsonschema,editpriv,viewpriv,description,label,netdb_visible,netdb_editable from 
        metadata_fields order by field";
    my $cid = $db->SQL_OpenQuery($qry) || $html->ErrorExitSQL( $qry, "get metadata field info" );

    while ( my ( $field, $type, $schema, $editpriv, $viewpriv, $desc, $label, $visable, $editable )
        = $db->SQL_FetchRow($cid) )
    {
        next if ( $visable ne "Y" );
        next if ( $viewpriv && !$privs{$viewpriv} );

        my $fieldid = $field;
        $fieldid =~ s/[\.\:]/_/go;

        $html->StartBlockTable( "Edit Metadata ($field) - $label", 600 );
        print "<b>$desc</b><p>\n";

        print "<div id=\"editor_holder_$field\"></div>\n";
        print "<script>\n";

        print "var js_schema_$fieldid = ";
        eval { decode_json($schema) };
        if ( !$@ ) {
            print $schema . ";\n";
        }
        else {
            print "{};\n";
            print "// ", $@, "\n";
        }

        print "var js_val_$fieldid = ";
        my $content = $mdinfo->{$field}->{content};
        eval { decode_json($content) };
        if ( !$@ ) {
            print $content;
        }
        else {
            print '""';
        }
        print ";\n";

        print <<EOF;
var js_ph_$fieldid = document.getElementById("editor_holder_$fieldid");
var jse_$fieldid = new JSONEditor(js_ph_$fieldid,{
    schema: js_schema_$fieldid,
    startval: js_val_$fieldid
});
EOF
        if ( $editable ne "Y" || ( $editpriv && !$privs{$editpriv} ) ) {
            print "jse_$fieldid.disable();\n";
        }
        print "</script>\n";

        $html->EndBlockTable();
    }
    $db->SQL_CloseQuery($cid);

}

# Begin-Doc
# Name: DisplaySearchForms
# Type: function
# Description: output the hostname search form
# End-Doc
sub DisplaySearchForms {
    my $host = $rqpairs{"host"} || "";
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    print "Search for host: ";
    &HTMLHidden( "mode", "search" );
    &HTMLInputText( "host", 30, $host );
    print " ";
    &HTMLSubmit("Search");
    &HTMLEndForm();

    print "<p/>\n";

    print "<a href=\"create-host.pl\">Create a new host</a>\n";
}

$html->PageFooter();

