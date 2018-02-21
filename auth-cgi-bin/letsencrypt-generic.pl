#!/usr/bin/perl

# Begin-Doc
# Name: letsencrypt.pl
# Type: script
# Description: letsencrypt helper tool
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::HTMLUtil;
use Local::PrivSys;

use NetMaint::DB;
require NetMaint::HTML;
require NetMaint::Access;
use Data::Dumper;
use LWP;
use IO::Socket::SSL;
use JSON;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "LetsEncrypt Certificate Helper" );

$html->PageHeader();

my $mode    = $rqpairs{mode};
my $host    = $rqpairs{host};
my $adminpw = $rqpairs{password};

if ( $mode eq "request" ) {
    $host = lc $host;
    if ( $host !~ /\./ ) {
        $host .= ".spirenteng.com";
    }

    if ( $host !~ /\.spirenteng\.com/ ) {
        $html->ErrorExit("Supported only for .spirenteng.com hostnames.");
    }
    if ( !gethostbyname($host) ) {
        $html->ErrorExit("Host ($host) does not resolve, cannot proceed.");
    }

    my $access = new NetMaint::Access;
    my $edit_ok = $access->CheckHostEditAccess( host => $host, action => "update" );
    if ( !$edit_ok ) {
        $html->ErrorExit("No permission to edit host ($host), cannot proceed.");
    }

    #
    # Need to implement access check for edit permission here
    #

    $html->StartBlockTable( "LetsEncrypt Request", 800 );
    my $base = "/local/letsencrypt/dehydrated";
    chdir($base) || $html->ErrorExit("Failed to change dir");
    print "<pre>\n";
    system( "./dehydrated", "-c", "-d", $host );
    print "</pre>\n";
    $html->EndBlockTable();

    if ( !-e "$base/certs/$host/cert.pem" ) {
        $html->ErrorExit("Failed to obtain cert - if you see a rateLimited error, try again in a few hours");
    }

    $html->StartBlockTable("Certificate Details", 800);
    $html->StartInnerTable();
    
    $html->StartInnerRow();
    print "<td align=left>\n";

    print "<h2>Key</h2>\n";
    open( my $in, "$base/certs/$host/privkey.pem" );
    my $key_txt = join( "", <$in> );
    close($in);
    print "<pre>$key_txt</pre>\n";

    print "<h2>Certificate</h2>\n";
    open( my $in, "$base/certs/$host/cert.pem" );
    my $cert_txt = join( "", <$in> );
    close($in);
    print "<pre>$cert_txt</pre>\n";

    print "<h2>Chain</h2>\n";
    open( my $in, "$base/certs/$host/chain.pem" );
    my $chain_txt = join( "", <$in> );
    close($in);
    print "<pre>$chain_txt</pre>\n";

    open( my $in, "/local/letsencrypt/root.pem" );
    my $root_txt = join( "", <$in> );
    close($in);

    $html->EndInnerRow();
    $html->EndInnerTable();
    $html->EndBlockTable();

    print "<b>Certificate is good for 90 days from issuance. Come back here after 60 days to renew.</b><br>\n";
}

print "<p>\n";

&HTMLStartForm( &HTMLScriptURL, "POST" );
&HTMLHidden( "mode", "request" );

$html->StartBlockTable( "Certificate Request", 800 );
$html->StartInnerTable();

$html->StartInnerHeaderRow();
print "<td colspan=100%>This will work for any host in .spirenteng.com that you have edit permissions for.</td>\n";
$html->EndInnerHeaderRow();

$html->StartInnerRow();
print "<td>Hostname:</td>\n";
print "<td>";
&HTMLInputText( "host", 50, $rqpairs{host} );
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td colspan=100% align=center>";
&HTMLSubmit("Request");
print " ";
&HTMLReset();
print "</td>\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();

$html->StartBlockTable("Recently Generated -- please reuse exactly if possible", 800);
$html->StartInnerTable("Time", "Hosts");

open(my $in, "/local/letsencrypt/gen-cached-recent-certs.pl|");
my $recent = join("", <$in>);
close($in);

my $rinfo = decode_json($recent);

foreach my $result ( @{ $rinfo } )
{
    $html->StartInnerRow();
    print "<td>\n";
    print scalar(gmtime($result->{tstamp})) . " UTC";
    print "</td>\n";
    print "<td>\n";
    my $hosts = join(" ", @{ $result->{hosts} });
    print "<a href=\"?joint=on&host=$hosts\">$hosts</a>\n";
    print "</td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();
