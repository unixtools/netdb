#!/usr/bin/perl

# Begin-Doc
# Name: build-dhcp-conf.pl
# Type: script
# Description: build dhcp config files
# End-Doc

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
require NetMaint::DB;
require NetMaint::Util;
require NetMaint::Network;
require NetMaint::DHCP;
use Digest::MD5 qw(md5_hex);
use Local::AuthSrv;

use strict;

# This should not take 2 minutes
alarm(120);

my $db    = new NetMaint::DB;
my $util  = new NetMaint::Util;
my $net   = new NetMaint::Network;
my $dhcp  = new NetMaint::DHCP;
my $error = new NetMaint::Error;

my $force = 0;
if ( $ARGV[0] eq "-force" ) {
    $force = 1;
}

# Get name of this server
chomp( my $server = `/bin/hostname` );

my $polycom_pw_secret = &AuthSrv_Fetch(user => "polycom", instance => "pw-seed");

# Load host options once
print "Retrieving host dhcp options.\n";
$error->clear();
my $host_options = $dhcp->GetAllHostOptions();
$error->check_and_die();

print "Retrieving host admin options.\n";
$error->clear();
my $admin_options = $dhcp->GetAllAdminOptions();
$error->check_and_die();

print "Retrieving subnet dhcp options.\n";
$error->clear();
my $sn_options = $dhcp->GetAllSubnetOptions();
$error->check_and_die();

print "Retrieving subnet information.\n";
$error->clear();
my $subnets = $net->GetSubnets();
$error->check_and_die();

print "Retrieving subnet dynamic ranges.\n";
$error->clear();
my %sn_ranges;
foreach my $sn ( keys(%$subnets) ) {
    $sn_ranges{$sn} = [ $net->GetIPRanges( $sn, "dynamic" ) ];
    $error->check_and_die();
}

print "Retrieving subnet unreg ranges.\n";
$error->clear();
my %sn_unreg_ranges;
foreach my $sn ( keys(%$subnets) ) {
    $sn_unreg_ranges{$sn} = [ $net->GetIPRanges( $sn, "unreg" ) ];
    $error->check_and_die();
}

print "Generating server configs...\n";

print "Generating config file.\n";

my $fname     = "/local/config/data/dhcpd.conf";
my $lastfname = "/local/config/data-last/dhcpd.conf";

unlink( $lastfname . ".tmp" );
open( my $tmph, ">${lastfname}.tmp" );
open( my $inh,  $fname );
while ( defined( my $line = <$inh> ) ) {
    print $tmph $line;
}
close($inh);
close($tmph);

unlink($lastfname);
rename( $lastfname . ".tmp", $lastfname );

unlink( $fname . ".tmp" );
open( my $tmpfh, ">${fname}.tmp" );

print "Generating header.\n";
print $tmpfh "option domain-name \"mst.edu\";\n";
print $tmpfh "option domain-name-servers 131.151.247.40, 131.151.247.41;\n";
print $tmpfh "next-server ${server};\n";
print $tmpfh "one-lease-per-client true;\n";
print $tmpfh "option netbios-node-type 8;\n";
print $tmpfh "option netbios-name-servers 131.151.247.43, 131.151.247.44;\n";
print $tmpfh "ddns-update-style none;\n";
print $tmpfh "authoritative;\n";

print $tmpfh "\n";

# Define our local options
print $tmpfh "option jetdirect-cf code 144 = text;\n";

print $tmpfh "\n";
print $tmpfh "# JetDirect Config\n";
print $tmpfh "option space JetDirect;\n";
print $tmpfh "option JetDirect.jetdirect-cf code 144 = text;\n";

print $tmpfh "\n";
print $tmpfh "# Cisco WLS Data\n";
print $tmpfh "option space Cisco;\n";
print $tmpfh "option Cisco.lwapp-controllers code 241 = array of ip-address;\n";

print $tmpfh "\n";
print $tmpfh "# Cisco VOIP Data\n";
print $tmpfh "option cisco-voip-tftp-servers code 150 = array of ip-address;\n";

# Wyse Thin clients
print $tmpfh "option wyse-url code 161 = text;\n";
print $tmpfh "option wyse-root code 162 = text;\n";
print $tmpfh "option wyse-username code 184 = text;\n";
print $tmpfh "option wyse-password code 185 = text;\n";

print $tmpfh "\n";
print $tmpfh "option hpdm-gateway code 202 = text;\n";
print $tmpfh "\n";

# PolyCom
print $tmpfh "option polycom-boot-url code 66 = text;\n";
print $tmpfh "\n";

print "Generating known static system group.\n";
print $tmpfh "\n";
print $tmpfh "# Systems with static registrations\n";
print $tmpfh "group {\n";
print $tmpfh "\n";

my $qry = "select distinct a.host,a.ip,b.ether from ip_alloc a,ethers b where a.host=b.name order by a.host,b.ether";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

my %seen_ether = ();

while ( my ( $name, $ip, $ether ) = $db->SQL_FetchRow($cid) ) {
    my $peth = $util->FormatEther($ether);
    if ( $peth !~ /[A-F:]+/o ) {
        print $tmpfh "# Skipping host $name, invalid formatted ethernet addr.\n\n";
        next;
    }

    $seen_ether{$peth} = 1;

    my ( $hname, $dname ) = split( /\./, $name, 2 );

    my $ethname = $peth;
    $ethname =~ s/:/-/g;

    my $ipname = $ip;
    $ipname =~ s/\./-/g;

    my $disable_host = 0;
    if ( $host_options->{$name} ) {
        foreach my $option ( @{ $host_options->{$name} } ) {
            if ( $option =~ /#\s*NODHCP/ ) { $disable_host = 1; }
        }
    }
    if ( $admin_options->{$name} ) {
        foreach my $option ( @{ $admin_options->{$name} } ) {
            if ( $option =~ /#\s*DISABLE/ ) { $disable_host = 1; }
        }
    }

    print $tmpfh " host $ethname-$ipname {\n";
    if ($disable_host) {
        print $tmpfh "  deny booting;\n";
    }
    print $tmpfh "  fixed-address $ip;\n";
    print $tmpfh "  hardware ethernet $peth;\n";
    print $tmpfh "  option host-name \"$hname\";\n";
    print $tmpfh "  option domain-name \"$dname\";\n";

    foreach my $option ( @{ $host_options->{$name} } ) {
        foreach my $line ( split( /[\r\n]/, &ProcessHostOption( host => $name, ether => $ether, option => $option ) ) ) {
            next if ( $line eq "" );
            print $tmpfh "  ", $line, "\n";
        }
    }
    print $tmpfh " }\n\n";
}
print $tmpfh "} # end of static hosts group\n\n";

print "Generating known systems group.\n";
print $tmpfh "# Systems known for purpose of fully dynamic leases\n";
print $tmpfh "group {\n";
print $tmpfh "\n";

my $qry = "select distinct name,ether from ethers order by name,ether";
my $cid = $db->SQL_OpenQuery($qry);

while ( my ( $name, $ether ) = $db->SQL_FetchRow($cid) ) {
    my $peth = $util->FormatEther($ether);
    if ( $peth !~ /[A-F:]+/o ) {
        print $tmpfh "# Skipping host $name, invalid formatted ethernet addr.\n\n";
        next;
    }

    $seen_ether{$peth} = 1;

    my ( $hname, $dname ) = split( /\./, $name, 2 );
    my $ethname = $peth;
    $ethname =~ s/:/-/g;

    my $disable_host = 0;
    if ( $host_options->{$name} ) {
        foreach my $option ( @{ $host_options->{$name} } ) {
            if ( $option =~ /#\s*NODHCP/ ) { $disable_host = 1; }
        }

    }
    if ( $admin_options->{$name} ) {
        foreach my $option ( @{ $admin_options->{$name} } ) {
            if ( $option =~ /#\s*DISABLE/ ) { $disable_host = 1; }
        }
    }

    print $tmpfh " host $ethname {\n";
    if ($disable_host) {
        print $tmpfh "  deny booting;\n";
    }
    print $tmpfh "  option host-name \"$hname\";\n";
    print $tmpfh "  option domain-name \"$dname\";\n";
    print $tmpfh "  hardware ethernet $peth;\n";
    if ( $host_options->{$name} ) {
        foreach my $option ( @{ $host_options->{$name} } ) {
            foreach my $line (
                split(
                    /[\r\n]/,
                    &ProcessHostOption(
                        host   => $name,
                        ether => $ether,
                        option => $option
                    )
                )
                )
            {
                next if ( $line eq "" );
                print $tmpfh "  ", $line, "\n";
            }
        }
    }

    print $tmpfh " }\n\n";
}
print $tmpfh "} # end of known hosts group\n\n";

$db->SQL_CloseQuery($cid);

print "Generating ignored ethers group:\n";
print $tmpfh "# Systems known for purpose of ignoring any lease attempts (abusers/etc)\n";
print $tmpfh "group {\n";
print $tmpfh "\n";

my $qry = "select distinct ether from ignored_ethers";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

while ( my ($ether) = $db->SQL_FetchRow($cid) ) {
    my $peth = $util->FormatEther($ether);
    if ( $peth !~ /[A-F:]+/o ) {
        print $tmpfh "# Skipping ether $ether, invalid formatted ethernet addr.\n\n";
        next;
    }

    if ( $seen_ether{$ether} ) {
        print "Skipping ignore of ($ether), seen in other sections.\n";
        next;
    }

    my $ethname = $peth;
    $ethname =~ s/:/-/g;

    print $tmpfh " host ignore-$ethname {\n";
    print $tmpfh "  deny booting;\n";
    print $tmpfh "  hardware ethernet $peth;\n";
    print $tmpfh " }\n\n";
}
print $tmpfh "} # end of ignored hosts group\n\n";

#
# Now output subnet information
#

print "Generating subnet config.\n";
foreach my $sn ( sort( keys(%$subnets) ) ) {
    my $baseip = $sn;
    $baseip =~ s|/.*||gio;

    my $label = $subnets->{$sn}->{description};
    my $mask  = $subnets->{$sn}->{mask};
    my $gw    = $subnets->{$sn}->{gateway};
    my $tmpl  = $subnets->{$sn}->{template};

    # Default to 12 hours
    my $def_lease_time = 12 * 60 * 60;
    my $max_lease_time = 12 * 60 * 60;

    # Add to front of list to allow override with subnet options table
    if ( $tmpl eq "voip" ) {
        unshift( @{ $sn_options->{$sn} }, "option cisco-voip-tftp-servers 10.20.0.1" );
        unshift( @{ $sn_options->{$sn} }, "option ntp-servers ${gw}" );
        unshift( @{ $sn_options->{$sn} }, "boot-unknown-clients on" );
        $def_lease_time = 8 * 24 * 60 * 60;
        $max_lease_time = 8 * 24 * 60 * 60;
    }
    elsif ( $tmpl eq "short" ) {
        $def_lease_time = 5 * 60;
        $max_lease_time = 5 * 60;
    }
    elsif ( $tmpl eq "public" ) {
        $def_lease_time = 60 * 60;
        $max_lease_time = 60 * 60;
        unshift( @{ $sn_options->{$sn} }, "boot-unknown-clients on" );
    }

    #
    # Scan subnet for any default/max lease time overrides
    #
    foreach my $option ( @{ $sn_options->{$sn} } ) {
        next if ( $option =~ /^\s*#/o );
        if ( $option =~ /default-lease-time\s*(\d+)/ ) {
            $def_lease_time = $1;
        }
        if ( $option =~ /max-lease-time\s*(\d+)/ ) {
            $max_lease_time = $1;
        }
    }

    print $tmpfh "#\n";
    print $tmpfh "# $label\n";
    print $tmpfh "#\n";
    print $tmpfh "subnet $baseip netmask $mask {\n";
    print $tmpfh " default-lease-time $def_lease_time;\n";
    print $tmpfh " max-lease-time $max_lease_time;\n";

    if ($gw) {
        print $tmpfh " option routers ${gw};\n";
    }

    my $allow_unknown;
    foreach my $option ( @{ $sn_options->{$sn} } ) {
        next if ( $option =~ /^\s*#/o );
        $option =~ s/;*$//gio;

        #
        if ( $option =~ /boot-unknown-clients\s*(on|yes|true)\s*/io ) {
            $allow_unknown = 1;
            next;
        }
        elsif ( $option =~ /allow\s*unknown-clients\s*/io ) {
            $allow_unknown = 1;
            next;
        }

        next if ( $option =~ /known-clients/o );
        next if ( $option =~ /known clients/o );
        next if ( $option =~ /default-lease-time/o );
        next if ( $option =~ /max-lease-time/o );

        print $tmpfh " ${option};\n";

    }

    # now fetch ranges
    my @range_refs    = @{ $sn_ranges{$sn} };
    my @ur_range_refs = @{ $sn_unreg_ranges{$sn} };

    if ( $#ur_range_refs < 0 ) {
        if ( !$allow_unknown ) {
            print $tmpfh " deny unknown-clients;\n";
        }
        else {
            print $tmpfh "  allow unknown-clients;\n";
        }
        foreach my $option ( @{ $sn_options->{$sn} } ) {
            next if ( $option =~ /^\s*#/o );
            $option =~ s/;*$//gio;

            next if ( $option =~ /known-clients/o );
            next if ( $option =~ /known clients/o );

            # Don't need these range-specific
            next if ( $option =~ /default-lease-time/o );
            next if ( $option =~ /max-lease-time/o );

            print $tmpfh " ${option};\n";
        }
    }

    if ( $#range_refs >= 0 ) {
        print $tmpfh " pool {\n";
        print $tmpfh "  deny dynamic bootp clients;\n";

        if ( $#ur_range_refs >= 0 ) {
            if ( !$allow_unknown ) {
                print $tmpfh "  deny unknown-clients;\n";
            }
            else {
                print $tmpfh "  allow unknown-clients;\n";
            }
        }

        foreach my $rref (@range_refs) {
            my ( $a, $b ) = @{$rref};
            print $tmpfh "  range $a $b;\n";
        }
        foreach my $option ( @{ $sn_options->{$sn} } ) {
            next if ( $option =~ /^\s*#/o );
            $option =~ s/;*$//gio;

            next if ( $option =~ /known-clients/o );
            next if ( $option =~ /known clients/o );
            next if ( $option =~ /default-lease-time/o );
            next if ( $option =~ /max-lease-time/o );

            print $tmpfh " ${option};\n";
        }
        print $tmpfh " }\n\n";
    }

    # and the unreg ranges
    if ( $#ur_range_refs >= 0 ) {
        print $tmpfh " pool {\n";
        print $tmpfh "  deny dynamic bootp clients;\n";
        print $tmpfh "  allow unknown clients;\n";
        print $tmpfh "  deny known clients;\n";
        print $tmpfh "  default-lease-time 120;\n";
        print $tmpfh "  max-lease-time 120;\n";
        print $tmpfh "  option domain-name-servers netreg.srv.mst.edu;\n";
        print $tmpfh "  option netbios-name-servers netreg.srv.mst.edu;\n";
        print $tmpfh "\n";

        foreach my $rref (@ur_range_refs) {
            my ( $a, $b ) = @{$rref};
            print $tmpfh "  range $a $b;\n";
        }
        print $tmpfh " }\n\n";
    }

    print $tmpfh "}\n\n";
}
print "\n";
close($tmpfh);

print "Changes in dhcpd.conf since last build:\n";
open( my $diffh, "LANG=C /usr/bin/diff --speed-large-files -u ${lastfname} ${fname}.tmp|" );
my $diffcnt = 0;
while ( defined( my $line = <$diffh> ) ) {
    $diffcnt++;
    print $line;
}
close($diffh);
if ( $diffcnt == 0 ) {
    print "No changes found.\n";
}
print "\n";

print "Checking dhcpd.conf for errors:\n";

open( my $checkh, "/local/dhcp/sbin/dhcpd -t -cf ${fname}.tmp 2>&1 |" );
my $errcnt  = 0;
my $saw_hdr = 0;
while ( defined( my $line = <$checkh> ) ) {
    if ( $line =~ /^Internet Software Consort/o ) {
        $saw_hdr = 1;
        next;
    }
    if ( $line =~ /^Internet Systems Consort/o ) {
        $saw_hdr = 1;
        next;
    }
    next if ( $line =~ /^Copyright /o );
    next if ( $line =~ /^All rights reserved/o );
    next if ( $line =~ /^For info, please visit/o );
    last if ( $line =~ /If you did not get this software/o );
    $errcnt++;
    print $line;
}
close($checkh);
if ( !$saw_hdr ) {
    print "Didn't see ISC header, syntax check not performed.\n";
}
elsif ( $errcnt == 0 ) {
    print "No errors found.\n";
}
print "\n";

if ( $diffcnt == 0 && !$force ) {
    print "DHCP config unchanged. Not installing new version.\n";
}
elsif ( !$saw_hdr ) {
    print "Didn't see ISC header. Not installing unchecked version.\n";
}
elsif ( $errcnt != 0 ) {
    print "Errors found in DHCP config. Not installing new version.\n";
}
else {
    print "New config file acceptable. Installing new version.\n";
    rename( $fname . ".tmp", $fname );

    my $realfile = "/local/dhcp-root/etc/dhcpd.conf";
    my $tmpfile  = $realfile . ".tmp";
    unlink($tmpfile);
    open( my $inconf,  $fname );
    open( my $outconf, ">" . $tmpfile );
    my $linecount = 0;
    while ( defined( my $line = <$inconf> ) ) {
        print $outconf $line;
        $linecount++;
    }
    close($outconf);
    close($inconf);

    if ( $linecount > 50000 ) {
        rename( $tmpfile, $realfile );

        # Restart the dhcp server
        print "Restarting DHCP server.\n";
        system("/local/netdb/bin/dhcp/run-dhcpd.pl");
    }
    else {
        $errcnt++;
        print "Not updating, new config has too few lines.\n";
        print "Line Count: $linecount\n";
    }
}

if ( $errcnt > 0 ) {
    print "Sending build failure message.\n";
    open( my $mail, "|/usr/sbin/sendmail -t" );
    print $mail "To: nneul\@mst.edu\n";
    print $mail "From: sysmon\@mst.edu\n";
    print $mail "Subject: DHCP config build failure.\n";
    print $mail "\n\nSee dhcp server logs for content of error. Build failed.\n";
    close($mail);
}

# Build tftp area
print "Building tftp area.\n";
system("/local/netdb/bin/dhcp/build-tftp.pl");
system("chown -R tftp:tftp /local/tftp");
system("chmod -R go-w /local/tftp");

print "\n";

print "Importing new files into repository.\n";
system("/local/netdb/bin/dhcp/archive-dhcp-config.pl");

print "Synchronizing standby server.\n";
system("/local/netdb/bin/dhcp/sync-standby.pl");

exit(0);

#
# Utility routines for expanding content of dhcp options - only used when building config
#

# Begin-Doc
# Name: ProcessHostOption
# Type: method
# Description: Returns array of lines for a given host option text
# Syntax: @lines = &ProcessHostOption(host => $host, ether => $ether, option => $option);
# End-Doc
sub ProcessHostOption {
    my %opts   = @_;
    my $host   = $opts{host};
    my $name   = $host;
    my $option = $opts{option};
    my $ether = $opts{ether};
    my $conf   = "";

    my $shortname = $name;
    $shortname =~ s/\..*//gio;

    $option =~ s/;*$//gio;

    my $optname = $option;
    $optname =~ s/^#\s*//go;
    $optname =~ s/\s+.*$//go;

    if (0) {
    }
    elsif ( $optname eq "PXE-SERVERS" ) {
        $conf .= <<EO_PXE_SERVERS;
filename "/pxe-servers/gpxelinux.0";
EO_PXE_SERVERS
    }
    elsif ( $optname eq "PXE-SERVERS-TEST" ) {
        $conf .= <<EO_PXE_SERVERS_TEST;
filename "/pxe-servers-test/gpxelinux.0";
EO_PXE_SERVERS_TEST
    }
    elsif ( $optname eq "PXE-WYSE" ) {
        $conf .= <<EO_PXE_WYSE;
filename "/pxe-wyse/gpxelinux.0";
option wyse-url "http://131.151.249.129/wyse";
EO_PXE_WYSE
    }
    elsif ( $optname eq "PXE-RST" ) {
        $conf .= <<EO_PXE_RST;
filename "/pxe-rst/pxelinux.0";
EO_PXE_RST
    }
    elsif ( $optname eq "PXE-DI-WINDOWS" ) {
        $conf .= <<EO_PXE_DI_WINDOWS;
filename "/pxe-di-windows/pxelinux.0";
EO_PXE_DI_WINDOWS
    }
    elsif ( $optname eq "NETCONF-AP-WLSE" ) {
        $conf .= <<EO_NETCONF_AP_WLSE;
next-server wlse01.network.mst.edu;
filename "$shortname";
EO_NETCONF_AP_WLSE
    }
    elsif ( $optname eq "NETCONF-AP-LWAPP-MESH" ) {
        $conf .= <<EO_NETCONF_AP_LWAPP;
if (option vendor-class-identifier = "Airespace.AP1200" )
{
    option vendor-encapsulated-options "131.151.2.193";
}
else
{
    vendor-option-space Cisco;
    option Cisco.lwapp-controllers 131.151.2.193;
}
EO_NETCONF_AP_LWAPP
    }
    elsif ( $optname eq "NETCONF-AP-LWAPP" ) {
        $conf .= <<EO_NETCONF_AP_LWAPP;
if (option vendor-class-identifier = "Airespace.AP1200" )
{
    option vendor-encapsulated-options "131.151.2.195";
}
else
{
    vendor-option-space Cisco;
    option Cisco.lwapp-controllers 131.151.2.195;
}
EO_NETCONF_AP_LWAPP
    }
    elsif ( $optname eq "JETDIRECT-STANDARD" ) {
        $conf .= <<EO_JETDIRECT;
option jetdirect-cf "jetdirect/standard";
vendor-option-space JetDirect;
option jetDirect.jetdirect-cf "jetdirect/standard";
EO_JETDIRECT
    }
    elsif ( $optname eq "JETDIRECT-OPEN" ) {
        $conf .= <<EO_JETDIRECT;
option jetdirect-cf "jetdirect/open";
vendor-option-space JetDirect;
option jetDirect.jetdirect-cf "jetdirect/open";
EO_JETDIRECT
    }
    elsif ( $optname eq "PXE-CMSERVER-PROD" ) {
        $conf .= <<EO_PXE_CMSRV_PROD;
filename "smsboot\\\\x86\\\\wdsnbp.com";
next-server cmserver-pxe.srv.mst.edu;
EO_PXE_CMSRV_PROD
    }
    elsif ( $optname eq "PXE-CMSERVER-TEST" ) {
        $conf .= <<EO_PXE_CMSRV_TEST;
filename "smsboot\\\\x86\\\\wdsnbp.com";
next-server cmserver-tpxe.srv.mst.edu;
EO_PXE_CMSRV_TEST
    }
    elsif ( $optname eq "PXE-CMDESK-PROD" ) {
        $conf .= <<EO_PXE_CMDESK_PROD;
filename "smsboot\\\\x86\\\\wdsnbp.com";
next-server cmdesk-pxe.srv.mst.edu;
EO_PXE_CMDESK_PROD
    }
    elsif ( $optname eq "PXE-CMDESK-TEST" ) {
        $conf .= <<EO_PXE_CMDESK_TEST;
filename "smsboot\\\\x86\\\\wdsnbp.com";
next-server cmdesk-tpxe.srv.mst.edu;
EO_PXE_CMDESK_TEST
    }
    elsif ( $optname eq "HP-THINCLIENT" ) {

        #hpdm-t1.srv.mst.edu
        $conf .= <<EO_HP_TC;
option hpdm-gateway "131.151.248.101 131.151.248.101";
EO_HP_TC
    }

    elsif ( $optname =~ /VOIP-POLY-SP-(\d+)/ ) {
        my $model = $1;

        my $pc_user = lc($ether);
        $pc_user =~ tr/a-f0-9//cd;

        my $pc_pw = substr(lc(md5_hex(lc($pc_user . $polycom_pw_secret))),0,12);

        $conf .= <<EO_VOIP;
option polycom-boot-url "http://${pc_user}:${pc_pw}\@xsp.evs.fidnet.com/dms/polycom$model";
EO_VOIP

    }
    elsif ( $option ne "" ) {
        $conf .= "${option};\n";
    }

    return $conf;
}
