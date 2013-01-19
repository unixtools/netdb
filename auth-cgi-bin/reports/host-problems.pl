#!/usr/bin/perl

# Begin-Doc
# Name: host-problems.pl
# Type: script
# Description: Report on problems with host registrations
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DHCP;
require NetMaint::DB;
require NetMaint::Logging;
require NetMaint::Hosts;
require NetMaint::Access;
require NetMaint::HostSeen;

use UMR::PrivSys;
use UMR::SysProg::ADSObject;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $mode = $rqpairs{"mode"};

my $dhcp    = new NetMaint::DHCP;
my $html    = new NetMaint::HTML;
my $log     = new NetMaint::Logging;
my $hosts   = new NetMaint::Hosts;
my $acc     = new NetMaint::Access;
my $hs      = new NetMaint::HostSeen;
my $network = new NetMaint::Network;

my $ads = new UMR::SysProg::ADSObject( use_gc => 1 );

$log->Log();

$html->PageHeader( title => "Hosts Problem Report" );

my $db = new NetMaint::DB;

#
# Build up list of valid userids
#
my %valid_users   = ();
my %invalid_users = ();

#
# Check owner for possibly off-site users
#
sub check_user {
    my $user = shift;
    if ( $valid_users{$user} || $invalid_users{$user} ) {
        return;
    }
    if ( my $info = $ads->GetAttributes($user) ) {
        my $dn = $info->{distinguishedName}[0];

        if ( $dn !~ /DC=umac/i ) {
            $valid_users{$user} = 1;
            return;
        }
    }
    else {
        $invalid_users{$user} = 1;
    }
}

#
# Build up the list of problems
#
print "Building host name problem list.<br/>\n";
my %problems = ();

my $qry = "select host,owner from hosts order by host";
my $cid = $db->SQL_OpenQuery($qry)
    || $html->ErrorExitSQL( "select hostnames", $db );

while ( my ( $name, $owner ) = $db->SQL_FetchRow($cid) ) {

    if ( $name =~ /^r\d\d(.+?)\./ ) {
        my $name_owner = $1;

        if ( $owner ne $name_owner ) {
            push( @{ $problems{$name} }, "Invalid Owner: have '$owner' but should have '$name_owner'" );

            &check_user($name_owner);

            if ( !$valid_users{$name_owner} ) {
                push( @{ $problems{$name} }, "Invalid UserID: owner '$name_owner' in host name does not exist" );
            }
        }
    }

    &check_user($owner);
    if ( !$valid_users{$owner} ) {
        push( @{ $problems{$name} }, "Invalid UserID: owner '$owner' does not exist locally" );

        my $info = $ads->GetAttributes($owner);
        if ($info) {
            my ($dn) = @{ $info->{distinguishedName} };
            $dn =~ s/^.*?dc=/dc=/io;
            $dn = lc $dn;
            if ($dn) {
                push( @{ $problems{$name} }, "Offsite Owner: $dn" );

            }
            else {
                push( @{ $problems{$name} }, "No Such UserID: owner '$owner' in host not found in forest" );
            }
        }

    }

    if ( $owner ne lc($owner) ) {
        my $lcowner = lc($owner);
        push( @{ $problems{$name} }, "Owner Case Mismatch: owner '$owner' does not match '$lcowner'" );
    }
    if ( $name ne lc($name) ) {
        my $lcname = lc($name);
        push( @{ $problems{$name} }, "Name Case Mismatch: hostname '$name' does not match '$lcname'" );
    }
}
print "Done.<br/>\n";

#
# Build up the DNS problem list
#
my $qry
    = "select name,address from dns_cname where "
    . "address not in (select host from hosts) "
    . "and address not in (select name from dns_a) "
    . "and address not in (select name from dns_cname) order by name";
my $cid = $db->SQL_OpenQuery($qry)
    || $html->ErrorExitSQL( "select dns_cname", $db );
while ( my ( $name, $address ) = $db->SQL_FetchRow($cid) ) {
    if ( $address =~ /\.mst\.edu$/o ) {
        push( @{ $problems{$name} }, "Invalid CName: target '$address' does not exist in netdb" );
    }
    else {
        if ( !gethostbyname($address) ) {
            push( @{ $problems{$name} }, "Invalid CName: target '$address' does not resolve in dns" );
        }
    }
}

#
# Non-Owned Hosts
#
my $qry = "select host,owner from hosts where (owner is null or owner='' or owner='namesrv') and type = 'desktop'";
my $cid = $db->SQL_OpenQuery($qry)
    || $html->ErrorExitSQL( "select non-owned", $db );
while ( my ( $name, $owner ) = $db->SQL_FetchRow($cid) ) {
    push( @{ $problems{$name} }, "Missing Owner: owner '$owner' not valid for desktop hosts" );
}

#
# Now, calculate the last seen subnet for each host
#
print "Determining last seen location for each host.<br/>\n";
my %host_subnets = ();
my %sn_to_hosts;
foreach my $host ( sort( keys(%problems) ) ) {
    my $info = $hs->GetHostLastSeen($host);
    my $sn;
    if ( $info && $info->{subnet} ) {
        $sn = $info->{subnet};
    }
    else {
        $sn = "0.0.0.0/0";
    }
    $host_subnets{$host} = $sn;
    $sn_to_hosts{$sn}->{$host} = 1;
}
print "Done.<br/>\n";

#
# Generate the report
#
$html->StartMailWrapper("Hosts Problem Report");
$html->StartBlockTable( "Host Problems", 800 );
$html->StartInnerTable();

$html->StartInnerHeaderRow();
print "<td width=180><b><a href=\"?sort=subnet\">Subnet</a></b></td>\n";
print "<td><b><a href=\"?sort=host\">Host</a></b></td>\n";
print "<td><b>Problems</b></td>\n";
$html->EndInnerHeaderRow();

my $cnt_hosts         = 0;
my $cnt_problems      = 0;
my %cnt_problems_type = ();
my %cnt_subnets       = ();

my @hosts = keys(%problems);
my @sorted;

if ( $rqpairs{sort} eq "subnet" ) {
    my @sorted_sn = $network->NetworkSort( keys %sn_to_hosts );
    foreach my $sn (@sorted_sn) {
        push( @sorted, sort keys %{ $sn_to_hosts{$sn} } );
    }
}
else {
    @sorted = sort(@hosts);
}

my $sninfo = $network->GetSubnets();

foreach my $host (@sorted) {
    $cnt_hosts++;

    $html->StartInnerRow();
    print "<td>";
    my $sn = $host_subnets{$host};
    print $sninfo->{$sn}->{description}, "<br/>\n", $sn;
    $cnt_subnets{$sn}++;
    print "</td>\n";

    print "<td>";
    my $bolded;
    my $font;
    if ( $host =~ /mst\.edu$/ ) {
        print "<b>";
        $bolded = 1;
    }
    print $html->SearchLink_Host($host), "</td>\n";
    print "<td>\n";
    if ( $host =~ /mst\.edu$/ ) {
        print "<b><font color=red>";
        $bolded = 1;
        $font   = 1;
    }

    my @probs = @{ $problems{$host} };
    $cnt_problems += scalar(@probs);

    foreach my $prob (@probs) {
        my $tprob = $prob;
        $tprob =~ s/:.*//g;
        $cnt_problems_type{$tprob}++;
    }

    if ( scalar(@probs) > 1 ) {
        $cnt_problems_type{"Multiple Problems"}++;
    }

    print join( "<br/>\n", @probs );
    if ($font) {
        print "</font>";
    }
    if ($bolded) {
        print "</b>";
    }
    print "</td>\n";
    $html->EndInnerRow();
}

$html->StartInnerHeaderRow();
print "<td valign=top><b>Top 10 Subnets:</b><br/>";
my $i = 0;
foreach my $sn ( sort { $cnt_subnets{$b} <=> $cnt_subnets{$a} || $b cmp $a } ( keys(%cnt_subnets) ) ) {
    last if ( ++$i > 10 );
    print $sn, ": ", $cnt_subnets{$sn}, "<br/>\n";
}
print "</td>\n";
print "<td valign=top><b>$cnt_hosts hosts</b></td>\n";
print "<td valign=top><b>$cnt_problems problems:</b><br/>";
foreach my $prob ( sort( keys(%cnt_problems_type) ) ) {
    print $prob, ": ", $cnt_problems_type{$prob}, "<br/>\n";
}
print "</td>\n";
$html->EndInnerHeaderRow();

$html->EndInnerTable();
$html->EndBlockTable();

$html->EndMailWrapper();

$html->PageFooter();

