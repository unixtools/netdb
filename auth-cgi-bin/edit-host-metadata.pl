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
    &CheckHostAndEditAccess();

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

    print <<JS_HEAD;
<link rel="stylesheet" href="/~netdb/js/jquery-ui-themes/themes/smoothness/jquery-ui.css" />
<link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/font-awesome/4.0.3/css/font-awesome.css" />

<script type="text/javascript" src="/~netdb/js/jquery.min.js"></script>
<script type="text/javascript" src="/~netdb/js/jquery-ui/jquery-ui.min.js"></script>
<script type="text/javascript" src="/~netdb/js/json-editor/dist/jsoneditor.min.js"></script>
<script type="text/javascript">
JSONEditor.defaults.options.iconlib = 'fontawesome4';
</script>

<script type="text/javascript">
function jse_save(host,fieldid,field,jse)
{
    console.log("marking " + fieldid + " saved");

    var val = JSON.stringify(jse.getValue());
    console.log("value = " + val);

    \$.ajax("ajax-metadata-update.pl?" +
        "host=" + encodeURIComponent(host) + 
        "&field=" + encodeURIComponent(field) + 
        "&value=" + encodeURIComponent(val), {
            dataType: "json",
        }).always( function(data,status,xhr) {

        if ( status == "success" )
        {
            if ( data.status != "ok" )
            {
                alert(data.message);
            }
            else
            {
                jse_mark_clean(fieldid);
                console.log("save ok = " + JSON.stringify(data));
            }
        }
        else
        {
            alert("save failed: " + status);
            console.log("save failed = " + xhr.responseText);
        }
    });
}


function jse_mark_dirty(fieldid)
{
    var dname;

    console.log("marking " + fieldid + " dirty");

    dname="jse_save1_" + fieldid;
    document.getElementById(dname).style.color="#ff0000";
    document.getElementById(dname).style.fontWeight="bolder";
    dname="jse_save2_" + fieldid;
    document.getElementById(dname).style.color="#ff0000";
    document.getElementById(dname).style.fontWeight="bolder";
}

function jse_mark_clean(fieldid)
{
    var dname;

    console.log("marking " + fieldid + " clean");

    dname="jse_save1_" + fieldid;
    document.getElementById(dname).style.color="#000000";
    document.getElementById(dname).style.fontWeight="normal";
    dname="jse_save2_" + fieldid;
    document.getElementById(dname).style.color="#000000";
    document.getElementById(dname).style.fontWeight="normal";
}

</script>
JS_HEAD

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

        print <<EOF;
<script>
var jse_$fieldid;
</script>
EOF

        $html->StartBlockTable( "Edit Metadata ($field) - $label", 600 );
        print "<b>$desc</b><p>\n";

        print
            "<button id=\"jse_save1_$fieldid\" onclick=\"jse_save('$host','$fieldid','$field',jse_$fieldid);\">Save</button> ";
        print "<p/>\n";
        print "<div id=\"editor_holder_$fieldid\"></div>\n";
        print "<p/>\n";
        print
            "<button id=\"jse_save2_$fieldid\" onclick=\"jse_save('$host','$fieldid','$field',jse_$fieldid);\">Save</button> ";
        print "<script>\n";

        print "var js_schema_$fieldid = ";
        eval { decode_json($schema) };
        if ( !$@ ) {
            print $schema . ";\n";
        }
        else {
            print "null;\n";
            print "// ", $@, "\n";
        }

        print "var js_val_$fieldid = ";
        my $content = $mdinfo->{$field}->{content};
        eval { decode_json($content) };
        if ( !$@ ) {
            print $content;
        }
        else {
            print 'null';
        }
        print ";\n";

        print <<EOF;
jse_$fieldid = new JSONEditor(
    document.getElementById("editor_holder_$fieldid"),
    {
        schema: js_schema_$fieldid,
        startval: js_val_$fieldid
    }
);

jse_changecount_$field = 0;
jse_$fieldid.on('ready',function() { console.log("$fieldid now ready"); jse_mark_clean('$fieldid'); });
jse_$fieldid.on('change',function() { 
    if ( jse_changecount_$fieldid > 0 )
    { 
        jse_mark_dirty('$fieldid'); 
    }
    jse_changecount_$fieldid++;
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

# Begin-Doc
# Name: CheckHostAndEditAccess
# Description: check if host exists and if user has rights to edit it
# End-Doc
sub CheckHostAndEditAccess {
    if ( !$host ) {
        $html->ErrorExit("No host specified.");
    }

    my $info = $hosts->GetHostInfo($host);
    if ( !$info ) {
        $html->ErrorExit( "Host (" . $html->Encode($host) . ") not found." );
    }

    my $edit_ok   = $access->CheckHostEditAccess( host => $host, action => "update" );
    my $delete_ok = $access->CheckHostEditAccess( host => $host, action => "delete" );

    if ( !$edit_ok && !$delete_ok ) {
        $html->ErrorExit( "Access denied to view/edit host (" . $html->Encode($host) . ")" );
    }
}

$html->PageFooter();

