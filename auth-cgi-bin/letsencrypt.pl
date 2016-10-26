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

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
IO::Socket::SSL::set_ctx_defaults(
    SSL_verifycn_scheme => 'www',
    SSL_verify_mode     => 0,
);

&HTMLStartForm( &HTMLScriptURL, "POST" );
&HTMLHidden( "mode", "install" );

$html->StartBlockTable( "Certificate Request", 800 );
$html->StartInnerTable();

$html->StartInnerHeaderRow();
print "<td colspan=100%>Currently supported only for iTE/Velocity instances</td>\n";
$html->EndInnerHeaderRow();

$html->StartInnerRow();
print "<td>Hostname:</td>\n";
print "<td>";
&HTMLInputText( "host", 50, $rqpairs{host} );
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td>Admin Password: (admin by default)</td>\n";
print "<td>";
&HTMLInputPassword( "password", 20, $rqpairs{password} ? $rqpairs{password} : "admin" );
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td>Restart System: </td>\n";
print "<td>";
&HTMLCheckbox("restart", 1);
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td colspan=100% align=center>";
&HTMLSubmit("Request and Install");
print " ";
&HTMLReset();
print "</td>\n";
$html->EndInnerRow();

$html->EndInnerTable();
$html->EndBlockTable();
&HTMLEndForm();

print "<p>\n";

if ( $mode eq "install" ) {
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

    my $ua = new LWP::UserAgent;

    my $reqinfo = {
        "action"     => "get",
        "attributes" => [ "SSL_X509_CERTFILE", "SSL_TRUST_CERTS", "SSL_X509_CHAIN", "SSL_X509_KEYFILE" ]
    };
    my $reqjson = encode_json($reqinfo);

    my $req = HTTP::Request->new( POST => "https://$host/configapi" );
    $req->content_type("application/json");
    $req->authorization_basic( "admin", $adminpw );
    $req->content($reqjson);

    my $res  = $ua->request($req);
    my $resp = $res->content();

    my $info;
    eval { $info = decode_json($resp); };
    if ( !$info ) {
        $html->ErrorExit("Received invalid json: $resp\n");
    }

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

    open( my $in, "$base/certs/$host/cert.pem" );
    my $cert_txt = join( "", <$in> );
    close($in);

    open( my $in, "$base/certs/$host/chain.pem" );
    my $chain_txt = join( "", <$in> );
    close($in);

    open( my $in, "$base/certs/$host/privkey.pem" );
    my $key_txt = join( "", <$in> );
    close($in);

    open( my $in, "/local/letsencrypt/root.pem" );
    my $root_txt = join( "", <$in> );
    close($in);

    # For now - later merge with existing
    my $new_trust = $root_txt;

    my $reqinfo = {
        "action"     => "set",
        "attributes" => {
            "SSL_X509_CERTFILE" => $cert_txt,
            "SSL_TRUST_CERTS"   => $new_trust,
            "SSL_X509_CHAIN"    => $chain_txt,
            "SSL_X509_KEYFILE"  => $key_txt
        }
    };

    if ( $rqpairs{restart} eq "on" ) {
        $reqinfo->{attributes}->{"ONESHOT_AUTO_REBOOT"}   = "yes";
        $reqinfo->{attributes}->{"ONESHOT_STOP_SERVICES"} = "yes";
    }

    my $reqjson = encode_json($reqinfo);

    my $req = HTTP::Request->new( POST => "https://$host/configapi" );
    $req->content_type("application/json");
    $req->authorization_basic( "admin", $adminpw );
    $req->content($reqjson);

    my $res  = $ua->request($req);
    my $resp = $res->content();

    my $info;
    eval { $info = decode_json($resp); };
    if ( !$info ) {
        $html->ErrorExit( "Received invalid json: " . $res->as_string );
    }

    if (0) {
        $html->StartBlockTable( "Appliance Config Output", 800 );
        print "<pre>\n";
        my $json = new JSON;
        print $json->pretty->canonical->encode($info);
        print "</pre>\n";
        $html->EndBlockTable();
    }

    print "<b>Appliance updated with new cert info, apply config or reboot to have it take effect.</b><br>\n";
    print "<b>Certificate is good for 90 days from issuance. Come back here after 60 days to renew.</b><br>\n";
}

$html->PageFooter();
