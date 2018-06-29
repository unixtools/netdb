#!/usr/bin/perl

# Begin-Doc
# Name: letsencrypt.pl
# Type: script
# Description: letsencrypt helper tool
# End-Doc
$| = 1;
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
print "<td>Host List</td>\n";
print "<td>";
&HTMLTextArea( "host", $rqpairs{host}, 60, 5 );
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td>Admin Password: (admin by default)</td>\n";
print "<td>";
&HTMLInputPassword( "password", 20, $rqpairs{password} ? $rqpairs{password} : "admin" );
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td>Combined Cert for All Hosts: </td>\n";
print "<td>";
&HTMLCheckbox( "joint", $rqpairs{joint} );
print " ";
print "<b>If you are generating certs for a set of instances, please use this when possible to reduce number of certificates requested.</b>\n";
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td>Restart System: </td>\n";
print "<td>";
&HTMLCheckbox( "restart", $rqpairs{restart} );
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
    my $ua = new LWP::UserAgent;
    $ua->timeout(3);

    my @hosts;
    foreach my $host ( split( /\s+/, lc $rqpairs{host} ) ) {
        if ( $host !~ /\./ ) {
            $host .= ".spirenteng.com";
        }
        if ( $host !~ /\.spirenteng\.com/ ) {
            $html->ErrorWarn("Supported only for .spirenteng.com hostnames.");
            next;
        }
        if ( !gethostbyname($host) ) {
            $html->ErrorWarn("Host ($host) does not resolve, cannot proceed.");
            next;
        }
        push( @hosts, $host );
    }

    my @host_sets = ();
    if ( $rqpairs{"joint"} eq "on" ) {
        @host_sets = ( [@hosts] );
    }
    else {
        @host_sets = ( map { [$_] } @hosts );
    }

    foreach my $hostset (@host_sets) {
        my $firsthost = $hostset->[0];
        print "<h3>Working on ", join( ", ", @$hostset ), "</h3>\n";

        $html->StartBlockTable( "LetsEncrypt Request", 800 );
        my $base = "/local/letsencrypt/dehydrated";
        chdir($base) || $html->ErrorExit("Failed to change dir");
        print "<pre>\n";

        my @cmd = ( "./dehydrated", "-c" );
        foreach my $host (@$hostset) {
            push( @cmd, "-d" => $host );
        }
        system(@cmd);
        print "</pre>\n";
        $html->EndBlockTable();

        print "Retrieving cert content for ($firsthost).<p>\n";

        if ( !-e "$base/certs/$firsthost/cert.pem" ) {
            $html->ErrorWarn("Failed to obtain cert - if you see a rateLimited error, try again in a few hours");
            next;
        }

        open( my $in, "$base/certs/$firsthost/cert.pem" );
        my $cert_txt = join( "", <$in> );
        close($in);

        open( my $in, "$base/certs/$firsthost/chain.pem" );
        my $chain_txt = join( "", <$in> );
        close($in);

        open( my $in, "$base/certs/$firsthost/privkey.pem" );
        my $key_txt = join( "", <$in> );
        close($in);

        open( my $in, "/local/letsencrypt/root.pem" );
        my $root_txt = join( "", <$in> );
        close($in);

        # For now - later merge with existing
        my $new_trust = $root_txt;

        foreach my $host (@$hostset) {
            my $reqinfo = {
                "action"     => "set",
                "attributes" => {
                    "SSL_X509_CERTFILE" => $cert_txt,
                    "SSL_TRUST_CERTS"   => $new_trust,
                    "SSL_X509_CHAIN"    => $chain_txt,
                    "SSL_X509_KEYFILE"  => $key_txt
                }
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
                $html->ErrorWarn("Received invalid json installing certs: $resp\n");
                next;
            }

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
                $html->ErrorWarn("Received invalid json: $resp\n");
                next;
            }

            if ( $rqpairs{restart} eq "on" ) {
                $reqinfo = {};
                $reqinfo->{action} = "set";
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
                $html->ErrorWarn( "Received invalid json: " . $res->as_string );
                next;
            }

            if (0) {
                $html->StartBlockTable( "Appliance Config Output", 800 );
                print "<pre>\n";
                my $json = new JSON;
                my $txt = $json->pretty->canonical->encode($info);
                print "</pre>\n";
                $html->EndBlockTable();
            }

            print
                "<b>Appliance $host updated with new cert info, apply config or reboot to have it take effect.</b><br>\n";
            print "<b>Certificate is good for 90 days from issuance. Come back here after 60 days to renew.</b><br>\n";
        }
    }
    print "<p>\n";
}

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
    my $hosts_print = join("<br>\n", @{ $result->{hosts} });
    my $hosts = join("+", @{ $result->{hosts} });
    print "<a href=\"?joint=on&host=$hosts\">$hosts_print</a>\n";
    print "</td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();
