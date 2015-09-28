#!/usr/bin/perl

# Begin-Doc
# Name: host-expiration.pl
# Type: script
# Description: Host expiration and fast-delete report
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Logging;
require NetMaint::DB;

use Local::PrivSys;
&PrivSys_RequirePriv("netmgr-user");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Subnet Host Expiration Report" );

if ( $mode eq "" ) {
    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    print "Host Expiration Report:<p/>";
    &HTMLHidden( "mode", "report" );
    print "Hosts to Display: ";
    &HTMLStartSelect( "count", 1 );
    print "<option>50\n";
    print "<option>100\n";
    print "<option selected>250\n";
    print "<option>500\n";
    print "<option>1000\n";
    print "<option>2500\n";
    print "<option value=-1>All\n";
    &HTMLEndSelect();
    print "<p/>\n";
    print "Host Pattern: ";
    &HTMLInputText( "pattern", 30 ), "<br/>\n";
    print "<p/>\n";
    print "Days to Show: ";
    &HTMLInputText( "days", 5, 180 ), "<br/>\n";
    print "<p/>\n";
    print "Enable Fast Delete Links: ";
    &HTMLCheckbox("fastdelete");
    print "<p/>\n";
    print "Show Record Types: ";
    &HTMLStartSelect( "types", 8, 1 );
    print "<option selected>device\n";
    print "<option>server\n";
    print "<option>cname\n";
    &HTMLEndSelect();
    print "<p/>\n";
    &HTMLSubmit("Search");
    &HTMLEndForm();
}
elsif ( $mode eq "report" ) {
    my $util    = new NetMaint::Util;
    my $db      = new NetMaint::DB;
    my $count   = int( $rqpairs{count} ) || 100;
    my $pat     = $rqpairs{pattern};
    my $showall = $rqpairs{showall} eq "on";
    my $days    = int( $rqpairs{days} );
    my $types   = $rqpairs{"types"};
    my @types;

    foreach my $type ( split( ' ', $types ) ) {
        if ( $type !~ /^[a-z]+$/o ) {
            $html->ErrorExit("Invalid type specified.");
        }
        push( @types, $db->SQL_QuoteString($type) );
    }

    print "Only hosts of type 'device' will be\n";
    print "automatically expired.\n";
    print "<p/>\n";

    $html->StartMailWrapper("Host Expiration Report");
    $html->StartBlockTable("Host Expiration Report");
    $html->StartInnerTable( "Type", "Host", "Expiration Date", "Options" );

    my $qry = "select type,host,purge_date from hosts " . "where purge_date < date_add(now(), interval ? day) ";
    $qry .= " and type in (" . join( ",", @types ) . ") ";
    $qry .= "order by purge_date";

    my $cid = $db->SQL_OpenQuery( $qry, $days ) || $db->SQL_Error($qry);
    my $i;
    while ( my ( $type, $host, $tstamp ) = $db->SQL_FetchRow($cid) ) {
        if ($pat) {
            next if ( $host !~ /$pat/o );
        }

        $html->StartInnerRow();
        print "<td>$type</td>\n";
        print "<td>", $html->SearchLink_Host($host), "</td>\n";
        print "<td>$tstamp</td>\n";
        print "<td><a target=deletewin href=\"/auth-cgi-bin/cgiwrap/netdb/edit-host.pl?mode=deletehost&host=";
        print $host, "\">Delete</a></td>";

        if ( $rqpairs{fastdelete} eq "on" ) {
            print
                "<td><a target=deletewin href=\"/auth-cgi-bin/cgiwrap/netdb/edit-host.pl?mode=deletehost&verify=yes&host=";
            print $host, "\">FastDelete</a></td>";
        }
        $html->EndInnerRow();

        $i++;
        last if ( $count > 0 && $i >= $count );
    }

    $html->StartInnerHeaderRow();
    print "<td colspan=4>\n";
    print "$i hosts.\n";
    print "</td>\n";
    $html->EndInnerHeaderRow();

    $html->EndInnerTable();
    $html->EndBlockTable();
    $html->EndMailWrapper();
}

$html->PageFooter();

