#!/usr/bin/perl

# Begin-Doc
# Name: live-dhcp-usage.pl
# Type: script
# Description: Report on current/live dhcp usage by subnet
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::AuthSrv;
use Data::Dumper;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DB;
require NetMaint::Logging;

use Local::PrivSys;
&PrivSys_RequirePriv("netdb-user");

&HTMLGetRequest();

my $mode = $rqpairs{"mode"};

my $html = new NetMaint::HTML;
$html->PageHeader( title => "DHCP Current Usage Status" );

my $log = new NetMaint::Logging;

$log->Log();

&AuthSrv_Authenticate( keep_ccache => 1 );

my $db = new NetMaint::DB;

# Now make sure every subnet shows up in list:
my $net    = new NetMaint::Network;
my $sninfo = $net->GetSubnets();

my %info;

#
# Load mapping info for ip to subnet
#
print "Loading mapping table... ";
my $qry        = "select ip,subnet,type from ip_alloc";
my $cid        = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
my %ip_to_sn   = ();
my %ip_to_type = ();
my %types      = ();
while ( my ( $ip, $sn, $type ) = $db->SQL_FetchRow($cid) ) {
    $ip_to_sn{$ip}   = $sn;
    $ip_to_type{$ip} = $type;
    $types{$type}    = 1;
}
$db->SQL_CloseQuery($cid);
print "Done.<br>\n";

#
# Load allocation by type
#
print "Loading allocation table... ";
my $qry = "select subnet,type,count(*) from ip_alloc group by subnet, type";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry);
while ( my ( $sn, $type, $cnt ) = $db->SQL_FetchRow($cid) ) {
    $info{$sn}->{$type}->{allocated} += $cnt;
}
$db->SQL_CloseQuery($cid);
print "Done.<br>\n";

#
# Start with zero tally for all
#
foreach my $sn ( keys(%$sninfo) ) {
    foreach my $type ( keys(%types) ) {
        $info{$sn}->{$type}->{allocated} += 0;
    }
}

#
# Now retrieve the leases file and summarize data
#
# $info{$sn}->{$addrtype}->{$status} = count;

# Purge known hosts in case it changes
print "Scanning DHCP lease status... ";
unlink("/local/netdb/.ssh/known_hosts");
my $tmpinfo;
my $ip;
my %seen;

foreach my $dhcpserver ( "fc-dhcp-ito.spirenteng.com", "fc-dhcp-ent.spirenteng.com" ) {
    print "Processing $dhcpserver...\n";
    open( STDERR_SV, ">&STDERR" );
    open( STDERR,    ">/dev/null" );
    open( my $in, "-|", "/usr/bin/ssh", "netdb\@$dhcpserver", "cat", "/local/dhcp-root/etc/dhcpd.leases" );
    open( STDERR, ">&STDERR_SV" );

    while ( defined( my $line = <$in> ) ) {
        if ( $line =~ /^lease\s+([\d\.]+)\s+{/o ) {
            if ($tmpinfo) {
                undef $tmpinfo;
            }

            $ip      = $1;
            $tmpinfo = {};
        }
        elsif ( $line =~ /^}/o ) {
            my $state = $tmpinfo->{state};
            my $ether = $tmpinfo->{ether};

            my $sn   = $ip_to_sn{$ip}   || "unknown";
            my $type = $ip_to_type{$ip} || "unknown";

            if ( !$seen{"$ip/$state"} ) {
                $info{$sn}->{$type}->{$state}++;
                $seen{"$ip/$state"} = 1;
            }
            undef $tmpinfo;
        }
        elsif ( $line =~ /^\s+binding state (.*?);/o ) {
            $tmpinfo->{state} = $1;
        }
        elsif ( $line =~ /^\s+hardware ethernet (.*?);/o ) {
            my $eth = uc $1;
            $eth =~ s/://go;
            $tmpinfo->{ether} = $eth;
        }
    }
    close($in);
}
print "Done.<br>\n";

#
# Gen report
#

$html->StartMailWrapper("DHCP Current Usage");

$html->StartBlockTable("DHCP Current Usage");
$html->StartInnerTable();

$html->StartInnerHeaderRow();
print "<td colspan=2>&nbsp;</td>\n";
print "<td colspan=3 align=center><b>Dynamic</b></td>\n";
print "<td colspan=3 align=center><b>Unreg</b></td>\n";
$html->EndInnerHeaderRow();

$html->StartInnerHeaderRow();
print "<td><b>Subnet</b></td>\n";
print "<td><b>Description</b></td>\n";
print "<td><b>Alloc</b></td>\n";
print "<td><b>Active</b></td>\n";
print "<td align=center><b>Graph</b></td>\n";
print "<td><b>Alloc</b></td>\n";
print "<td><b>Active</b></td>\n";
print "<td align=center><b>Graph</b></td>\n";
$html->EndInnerHeaderRow();

foreach my $sn ( $net->NetworkSort( keys(%$sninfo) ) ) {
    my $desc     = $sninfo->{$sn}->{description};
    my $d_alloc  = $info{$sn}->{dynamic}->{allocated} + 0;
    my $d_active = $info{$sn}->{dynamic}->{active} + 0;
    my $u_alloc  = $info{$sn}->{unreg}->{allocated} + 0;
    my $u_active = $info{$sn}->{unreg}->{active} + 0;
    my ( $gwidth, $rwidth );

    next if ( ( $d_alloc + $d_active + $u_alloc + $u_active ) == 0 );

    $html->StartInnerRow();
    print "<td>$sn</td>\n";
    print "<td>$desc</td>\n";

    my $maxwidth = 100;
    my $thresh   = 75;

    print "<td align=right>$d_alloc</td>\n";
    print "<td align=right>$d_active</td>\n";

    $gwidth = 0;
    $rwidth = 0;
    eval {
        $gwidth = int( ( ( $d_alloc - $d_active ) / $d_alloc ) * $maxwidth + 0.5 );
        $rwidth = int( ( $d_active / $d_alloc ) * $maxwidth + 0.5 );
    };

    print "<td>";
    if ( $rwidth > 0 ) {
        if ( $rwidth > $thresh ) {
            print "<img src=\"/~netdb/images/red.gif\" height=10 width=$rwidth>";
        }
        else {
            print "<img src=\"/~netdb/images/white.gif\" height=10 width=$rwidth>";
        }
    }
    if ( $gwidth > 0 ) {
        print "<img src=\"/~netdb/images/green.gif\" height=10 width=$gwidth>";
    }
    print "</td>\n";

    print "<td align=right>$u_alloc</td>\n";
    print "<td align=right>$u_active</td>\n";

    $gwidth = 0;
    $rwidth = 0;
    eval {
        $gwidth = int( ( ( $u_alloc - $u_active ) / $u_alloc ) * $maxwidth + 0.5 );
        $rwidth = int( ( $u_active / $u_alloc ) * $maxwidth + 0.5 );
    };
    print "<td>";
    if ( $rwidth > 0 ) {
        if ( $rwidth > $thresh ) {
            print "<img src=\"/~netdb/images/red.gif\" height=10 width=$rwidth>";
        }
        else {
            print "<img src=\"/~netdb/images/white.gif\" height=10 width=$rwidth>";
        }
    }
    if ( $gwidth > 0 ) {
        print "<img src=\"/~netdb/images/green.gif\" height=10 width=$gwidth>";
    }
    print "</td>\n";

    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

&AuthSrv_Unauthenticate();
$html->PageFooter();
