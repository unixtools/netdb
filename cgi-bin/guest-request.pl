#!/usr/bin/perl

# Begin-Doc
# Name: guest-request.pl
# Type: script
# Description: submit a guest registration request
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use UMR::Encode;
use Socket;

use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Logging;
require NetMaint::Leases;
require NetMaint::DHCP;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Guest Registration Request" );

$html->PageHeader();

my $db     = new NetMaint::DB;
my $leases = new NetMaint::Leases;
my $log    = new NetMaint::Logging;
my $dhcp   = new NetMaint::DHCP;
my $util   = new NetMaint::Util;

$log->Log();

my $mode = $rqpairs{mode};
my $addr = $ENV{"HTTP_X_FORWARDED_FOR"} || $ENV{REMOTE_ADDR};

if ( $mode eq "" ) {
    $html->StartBlockTable( "Guest Registration Request", 500 );
    $html->StartInnerTable();

    &HTMLStartForm( &HTMLScriptURL(), "GET" );
    &HTMLHidden( "mode", "submit" );

    $html->StartInnerRow();
    print "<td colspan=2>\n";
    print "In order to request guest network access, please\n";
    print "fill in the below information with your information, and\n";
    print "as much information as possible about the person or department\n";
    print "that is sponsoring your access. The hardware\n";
    print "address is filled in by default, if incorrect, please fill in the\n";
    print "correct address.\n";
    print "<p/>\n";
    print "<b>If you are a current student or employee/faculty, DO NOT\n";
    print "use this form. This form is only for GUESTS to the university that\n";
    print "do not have a UM System UserID.</b>\n";
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Your Name:</td>\n";
    print "<td>";
    &HTMLInputText( "name", 40 );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Your Phone:</td>\n";
    print "<td>";
    &HTMLInputText( "phone", 30 );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Your EMail:</td>\n";
    print "<td>";
    &HTMLInputText( "email", 30 );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Sponsor Name:</td>\n";
    print "<td>";
    &HTMLInputText( "sponsorname", 30 );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Sponsor Department:</td>\n";
    print "<td>";
    &HTMLInputText( "sponsordept", 30 );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Sponsor EMail:</td>\n";
    print "<td>";
    &HTMLInputText( "sponsoremail", 30 );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td>Sponsor Phone:</td>\n";
    print "<td>";
    &HTMLInputText( "sponsorphone", 30 );
    print "</td>\n";
    $html->EndInnerRow();

    my $ether = $leases->GetCurLeaseByIP($addr);
    $ether = $util->FormatEther($ether);

    $html->StartInnerRow();
    print "<td>Ethernet/Hardware Address:</td>\n";
    print "<td>";
    &HTMLInputText( "ether", 20, $ether );
    print "</td>\n";
    $html->EndInnerRow();

    $html->StartInnerRow();
    print "<td colspan=2>";
    &HTMLSubmit("Submit");
    print " ";
    &HTMLReset("Reset");
    print "</td>\n";
    $html->EndInnerRow();

    $html->EndInnerTable();
    $html->EndBlockTable();

}
else {
    my $bad = 0;
    if ( !$rqpairs{"sponsorname"} ) {
        print "<p/><b>You must provide the name of the sponsoring faculty or staff person.</b>\n";
        $bad = 1;
    }
    if ( !$rqpairs{"name"} ) {
        print "<p/><b>You must provide the name of the person requesting guest access to the network.</b>\n";
        $bad = 1;
    }
    if ( !$rqpairs{"sponsoremail"} ) {
        print "<p/><b>You must provide email contact information for the person sponsoring this network access.</b>\n";
        $bad = 1;
    }
    if ( !$rqpairs{"phone"} && !$rqpairs{"email"} ) {
        print
            "<p/><b>You must provide contact information for the person requesting guest access to the network.</b>\n";
        $bad = 1;
    }
    if ( $rqpairs{"sponsoremail"} !~ /^[a-z0-9-_.]+\@mst.edu/io ) {
        print "<p/><b>Sponsor email address must be \@mst.edu.</b>\n";
        $bad = 1;
    }
    if ( !$util->FormatEther( $rqpairs{"ether"} ) ) {
        print "<p/><b>You must provide a valid ethernet address for the machine being connected to the network.</b>\n";
        $bad = 1;
    }
    if ($bad) {
        print "<p/>\n";
        print "Request has <b>NOT</b> been submitted. Please click back and fill in the required fields.\n";
        $html->PageFooter();
        exit;
    }

    my $ether = $util->FormatEther( $rqpairs{ether} );

    open( my $mailfh, "|/usr/lib/sendmail -t" );
    print $mailfh "To: ", $rqpairs{sponsoremail}, "\n";
    print $mailfh "From: IT Network Registration Tool <ithelp\@mst.edu>\n";
    print $mailfh "Subject: Guest Registration Request\n";
    print $mailfh "Content-type: text/html\n";
    print $mailfh "\n\n";

    print $mailfh <<EOM;
The following IT Network Guest Registration request has been received. To
approve this request and create the guest registration, please click on the
link below. Note, if you do not know why this request has been submitted, it
is strongly suggested that you validate that it is appropriate before 
proceeding. As with all other network registrations, as the sponsor, you
are responsible for any and all network activity of this station.
<p/>
NOTE: If you do NOT intend to authorize or take responsibility for this
registeration, do NOT click on the link below.
<p/>
Click (or enter the URL in your browser) on the following link to register this system:
<p/>
EOM

    my $idx = &Encode_URLEncode("##");

    print $mailfh "<a href=\"https://itweb.mst.edu/auth-cgi-bin/cgiwrap/netdb/create-host.pl?";
    print $mailfh "mode=create&nametype=ownername&type=guest&index=%23%23&domain=guest.device.mst.edu&ether=$ether\">Register Guest</a>\n";

    print $mailfh "<p/>\n";

    print $mailfh "Request Details:<p/>\n";
    print $mailfh "<ul>\n";
    print $mailfh "<li>Name: ",          $html->Encode( $rqpairs{name} );
    print $mailfh "<li>Phone: ",         $html->Encode( $rqpairs{phone} );
    print $mailfh "<li>EMail: ",         $html->Encode( $rqpairs{email} );
    print $mailfh "<li>Ethernet Addr: ", $html->Encode($ether);

    print $mailfh "<p/>\n";

    print $mailfh "<li>Sponsor Name: ",  $html->Encode( $rqpairs{sponsorname} );
    print $mailfh "<li>Sponsor Dept: ",  $html->Encode( $rqpairs{sponsordept} );
    print $mailfh "<li>Sponsor Phone: ", $html->Encode( $rqpairs{sponsorphone} );
    print $mailfh "<li>Sponsor EMail: ", $html->Encode( $rqpairs{sponsoremail} );

    print $mailfh "<li>Remote IP: ", $html->Encode($addr);

    my $hn = "";
    if ($addr) {
        my $iaddr = inet_aton($addr);
        $hn = gethostbyaddr( $iaddr, AF_INET );
    }

    if ( $hn !~ /dyn-ether/o && $hn ne "" ) {
        print $mailfh "<li>Remote Host: ", $html->Encode($hn);
    }
    if ( $ENV{REMOTE_USER} ne "" ) {
        print $mailfh "<li>Remote User: ", $html->Encode( $ENV{REMOTE_USER} );
    }

    print $mailfh "</ul>\n";
    close($mailfh);

    print "Your request has been submitted.\n";
}

$html->PageFooter();

