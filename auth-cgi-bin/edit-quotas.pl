#!/usr/bin/perl

# Begin-Doc
# Name: edit-quotas.pl
# Type: script
# Description: edit user netdb registration quotas
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::PrivSys;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Register;
require NetMaint::Logging;

use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $html   = new NetMaint::HTML( title => "Edit Registration Quotas" );
my $util   = new NetMaint::Util;
my $access = new NetMaint::Access;
my $log    = new NetMaint::Logging;

$html->PageHeader();
$html->RequirePriv("netdb-admin");

$log->Log();

my $mode = $rqpairs{mode};
if ( $mode eq "Delete" ) {
    my $owner = $rqpairs{selectowner};
    $access->DeleteRegistrationQuota($owner);
    print "<h3>Quota for <tt>$owner</tt> removed.</h3>\n";

    $log->Log( "owner" => $owner );
}
elsif ( $mode eq "Update" ) {
    my $owner = lc $rqpairs{owner};
    my $quota = int( $rqpairs{quota} );

    if ( $quota < 0 || $quota > 100000 ) {
        $html->ErrorExit("Invalid quota specified.");
    }

    if ( !$util->UserInfo($owner) ) {
        $html->ErrorExit("Invalid userid specified.");
    }

    $access->UpdateRegistrationQuota( $owner, $quota );
    print "<h3>Quota for <tt>$owner</tt> updated to <tt>$quota</tt>.</h3>\n";

    $log->Log( "owner" => $owner );
}

print "<p/>\n";

my $info = $access->GetAllRegistrationQuotas();

&HTMLStartForm( &HTMLScriptURL, "GET" );
&HTMLStartSelect( "selectowner", 15 );

foreach my $owner ( sort( keys(%$info) ) ) {
    my $quota = $info->{$owner};
    print "<option value=\"$owner\">$owner: $quota\n";
}
&HTMLEndSelect();
print "<p/>\n";
&HTMLSubmit( "Delete", "mode" );
&HTMLEndForm();

print "<p/><hr/><p/>\n";
print "<h3>Add New Quota Exception:</h3> ";

&HTMLStartForm( &HTMLScriptURL, "GET" );
print "UserID: ";
&HTMLInputText( "owner", 20 );
print "  ";
print "Quota: ";
&HTMLInputText( "quota", 10 );
print "  ";
&HTMLSubmit( "Update", "mode" );

print "<p/>\n";
&HTMLEndForm();

print "<p/>\n";
$html->PageFooter();

