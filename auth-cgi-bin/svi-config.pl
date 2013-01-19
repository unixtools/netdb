#!/usr/bin/perl

# Begin-Doc
# Name: svi-config.pl
# Type: script
# Description: list of subnets
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Network;
require NetMaint::Logging;

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML( title => "Subnet SVI Config" );
my $log = new NetMaint::Logging;

my $mode = $rqpairs{mode} || "list";

$log->Log();

$html->PageHeader();
$html->RequirePriv("sysprog:netdb:alloc");

my $net     = new NetMaint::Network;
my $subnets = $net->GetSubnets();
my $vlans   = $net->GetVLANs();

if ( $mode eq "list" ) {

    print <<EOJS;
<style type="text/css">
     \@import "/~jstools/DataTables/media/css/demo_table.css";
.dataTables_wrapper {
    min-height: 60px;
}

.sn_mono {
    font-family: monospace;
}


</style>
<script type="text/javascript" src="/~jstools/jquery/jquery.js"></script>
<script type="text/javascript" src="/~jstools/DataTables/media/js/jquery.dataTables.js"></script>
<script type="text/javascript" src="/~netdb/subnet-sort.js"></script>
EOJS

    &HTMLStartForm( &HTMLScriptURL(), "GET" );

    print "This report indicates the currently defined subnets on the network.\n";
    print "<p/>\n";
    print "<a href=\"?\">Show server networks</a> | ";
    print "<a href=\"?showall=on\">Show all networks</a><p>";

    my $showall = $rqpairs{showall};

    $html->StartMailWrapper("Subnets");

    $html->StartBlockTable( "Subnets", 1000 );

    print "<table border=0 class=\"display\" id=\"subnets\">\n";

    print "<thead><tr><th>Subnet</th><th>Action</th><th>VLAN</th><th>Desc</th></tr></thead>\n";
    print "<tbody>\n";

    foreach my $sn ( $net->NetworkSort( keys( %{$subnets} ) ) ) {
        my $vlan      = $subnets->{$sn}->{vlan};
        my $vlan_name = $vlans->{$vlan}->{name};
        my $desc      = $subnets->{$sn}->{description};

        if ( $showall ne "on" ) {
            next if ( $desc !~ /^SRV/o && $vlan_name !~ /SRV/ );
        }

        print "<tr>\n";
        print "<td class=sn_mono>$sn</td>\n";
        print "<td class=sn_mono><a href=\"?mode=showconfig&subnet=", $html->Encode($sn), "\">$sn</a></td>\n";
        if ( !$vlan ) {
            print "<td class=sn_mono>&nbsp;</td>\n";
        }
        else {
            print "<td class=sn_mono>$vlan: $vlan_name</td>\n";
        }
        print "<td>$desc</td>\n";
        print "</tr>\n";
    }

    print "</tbody>\n";
    print "</table>\n";
    $html->EndBlockTable();

    print <<EOJS;
<script type="text/javascript">
   \$('#subnets').dataTable( {
        "bPaginate": false,
        "bAutoWidth": false,
        "bProcessing": true,
        "oLanguage": {
            "sSearch" : "Quick Search/Filter:"
        }
    });
</script>
EOJS

    $html->EndMailWrapper();

}
elsif ( $mode eq "showconfig" ) {
    print "<div style=\"width: 700px; text-align: justify\">\n";
    print
        "The following configuration should be applied to the datacenter routers to configure this subnet. Please do\n";
    print
        "not apply this blindly. This should be used as a reference only. This configuration is also hardwired for current\n";
    print
        "device names/types/etc. and will need to be updated in the code if physical configuration changes. This listing\n";
    print
        "also assumes subnets in the datacenter and is valid for other campus building router configuration. This listing\n";
    print "is for subnets in vrf DATA or NCCO-DATA only.\n<p>\n";
    print "</div>\n";

    my $sn        = $rqpairs{subnet};
    my $info      = $subnets->{$sn};
    my $vlan      = $subnets->{$sn}->{vlan};
    my $vlan_name = $vlans->{$vlan}->{name};

    if ( !$info ) {
        $html->ErrorExit("Undefined Subnet");
    }

    my $snip = $sn;
    $snip =~ s|/.*||go;

    my $bits = $sn;
    $bits =~ s|.*/||go;

    my $mask = $net->BitsToMask($bits);
    my $wc   = $net->BitsToWildcard($bits);

    my $maskint   = $net->IPToInteger($mask);
    my $subnetint = $net->IPToInteger($snip);

    my $bcint = $subnetint | ~$maskint;
    my $bc    = $net->IntegerToIP($bcint);

    # Standard in our env is to use last three addresses on subnet
    my $gw   = $net->IntegerToIP( $bcint - 1 );
    my $gwm1 = $net->IntegerToIP( $bcint - 2 );
    my $gwm2 = $net->IntegerToIP( $bcint - 3 );

    print "<!-- \n";
    print "<pre>\n";
    print "sn = $sn\n";
    print "snip = $snip\n";
    print "bits = $bits\n";
    print "mask = $mask\n";
    print "wc = $wc\n";
    print "bc = $bc\n";
    print "gw = $gw\n";
    print "gwm1 = $gwm1\n";
    print "gwm2 = $gwm2\n";
    print "</pre>\n";
    print "-->\n";

    print "<p>\n";
    print
        "Before proceeding, make sure that the following IPs are assigned and registered to the applicable hosts:<br>\n";

    my @addrs = (
        [ "itdc-ncco-100-vrfdata-rtr.network.mst.edu", $gwm2 ],
        [ "itdc-nccs-100-vrfdata-rtr.network.mst.edu", $gwm1 ],
        [ "itdc-hsrp-vrfdata-rtr.network.mst.edu",     $gw ],
    );

    if ( $vlan_name =~ /SNAT/ ) {
        @addrs = (
            [ "itdc-ncco-050-rtr.network.mst.edu", $gwm2 ],
            [ "itdc-nccs-050-rtr.network.mst.edu", $gwm1 ],
            [ "itdc-vrrp-050.network.mst.edu",     $gw ],
        );
    }

    $html->StartBlockTable( "Address Allocation and Registration", 700 );
    $html->StartInnerTable();
    foreach my $aref (@addrs) {
        my ( $host, $ip ) = @{$aref};
        my %info = $net->GetAddressDetail($ip);

        my $oldhost = $info{host};
        if ($oldhost) {
            $html->StartInnerRow();
            print "<td>$ip - Currently allocated to ";
            print "<a href=\"edit-host.pl?mode=view&host=$oldhost\">$oldhost</a></td><td>\n";
            print "<a href=\"edit-host.pl?mode=delstatic&host=${oldhost}&ip=${ip}\">Deregister</a></td>\n";
            $html->EndInnerRow();
        }

        if ( $oldhost eq $host ) {
            $html->StartInnerRow();
            print "<td>$ip - Is allocated to ";
            print "<a href=\"edit-host.pl?mode=view&host=$host\">$host</a></td><td>&nbsp;</td>\n";
            $html->EndInnerRow();
        }
        else {
            $html->StartInnerRow();
            print "<td>$ip - Needs to be allocated to ";
            print "<a href=\"edit-host.pl?mode=view&host=$host\">$host</a></td><td>\n";
            print
                "<a href=\"edit-host.pl?mode=addstatic&submode=selectip&host=${host}&address=${ip}\">Allocate</a></td>\n";
            $html->EndInnerRow();

        }

        $html->StartInnerRow();
        print "<td>$ip - Needs static dns for ";
        print "<a href=\"edit-host.pl?mode=view&host=$host\">$host</a></td><td>\n";
        print "<a href=\"edit-host.pl?mode=enable_static_dns&host=${host}&ip=${ip}\">Register DNS</a></td>\n";
        $html->EndInnerRow();
    }

    $html->EndInnerTable();
    $html->EndBlockTable();

    # Determine primary location of subnet
    my $vrf      = "DATA";
    my $ospfarea = "0.0.0.0";
    my $ospfinst = 1;
    my $nccoshut = "shutdown";
    if ( $snip =~ /^128.206/ ) {
        $vrf      = "NCCO-DATA";
        $nccoshut = "no shutdown";
        $ospfarea = "3.3.3.3";
        $ospfinst = "3333";
    }

    # IPv6 Address
    my $v6prefix = "2610:00e0:a020";         # for nccs datacenter
    my $v6cfg    = "! IPv6 Configuration";
    if ( $snip =~ /^131.151./ ) {
        $v6cfg .= <<EOV6;
! IPv6 SVIs are brought online in our setup by default blocking everything except certain
! icmp operations. This config will be replaced by aclmgr when acls are installed.
!
config term
ipv6 access-list DCACL6_VLAN_${vlan}_OUT
  1 permit tcp any any established
interface vlan ${vlan}
  ipv6 address 2610:00e0:a020:${vlan}::1/64
  ipv6 unreachables
  ipv6 traffic-filter DCACL6_VLAN_${vlan}_OUT out
end
EOV6
        $v6cfg =~ s/\n\n+/\n/sgmo;

        # for now
        $v6cfg =~ s/^/!/sgmo;
    }

    # 0200 prefix
    # 0002 hsrp group 2
    # hex vlan number
    my $mac = lc sprintf("0200.0002.%.4X", $vlan);

    $html->StartMailWrapper("Subnet Configuration - $sn");
    $html->StartBlockTable("Configuration Text - $sn");

    print "<pre>\n";
    print <<EOCONF;
!
! ITDC-NCCS-100 (Nexus 7000)
!
config term
vlan ${vlan}
  name ${vlan_name}
interface Vlan${vlan}
  shutdown
  description SVI N=${vlan_name}
  vrf member ${vrf}
  ip address ${gwm1}/${bits}
  ip access-group DCACL_VLAN_${vlan}_OUT out
  no ip redirects
  ip ospf cost 5000
  ip ospf passive-interface
  ip router ospf ITDC area ${ospfarea}
  ip pim sparse-mode
  hsrp version 2
  hsrp 2
    authentication text itdcgrp2
    mac-address ${mac}
    preempt
    ip ${gw}
  ip dhcp relay address 131.151.248.65
  ip dhcp relay address 131.151.248.66
end
!
$v6cfg
!
config term
ip access-list DCACL_VLAN_${vlan}_OUT
  statistics per-entry
end
!
! issue 'no shut' on the interface to bring online, otherwise leave shut down
!
config term
interface Vlan${vlan}
  no shut
end

! 
copy running-config startup-config

! Be sure to trigger a backup: /local/aclmgr/bin/trigger itdc-nccs-100

EOCONF

    print "<p>\n";

    print <<EOCONF;
!
! ITDC-NCCO-100 (Catalyst 4506)
!
config term
vlan ${vlan}
  name ${vlan_name}
interface Vlan${vlan}
  shutdown
  description SVI N=${vlan_name}
  ip vrf forwarding ${vrf}
  ip address ${gwm2} ${mask}
  ip access-group DCACL_VLAN_${vlan}_OUT out
  ip helper-address 131.151.248.65
  ip helper-address 131.151.248.66
  no ip redirects
  no ip proxy-arp
  ip pim sparse-mode
  ip ospf cost 5000
  standby version 2
  standby 2 ip ${gw}
  standby 2 priority 50
  standby 2 preempt
  standby 2 authentication itdcgrp2
  standby 2 mac-address ${mac}
!
  ip access-list extended DCACL_VLAN_${vlan}_OUT
!
  router ospf ${ospfinst} vrf ${vrf}
    network ${snip} ${wc} area ${ospfarea}
end
!
! issue 'no shut' on the interface to bring online, otherwise leave shut down
!
config term
interface Vlan${vlan}
  no shut
end

!
wr mem
! Be sure to trigger a backup: /local/aclmgr/bin/trigger itdc-ncco-001

EOCONF

    print "<p>\n";

    print <<EOCONF;
!
! Configuration to remove the subnet/interface
! ITDC-NCCS-100 (Nexus 7000)
config term
  no interface Vlan${vlan}
  no ip access-list DCACL_VLAN_${vlan}_IN
  no ip access-list DCACL_VLAN_${vlan}_OUT
end

copy running-config startup-config
! Be sure to trigger a backup: /local/aclmgr/bin/trigger itdc-nccs-100

!
!
! Configuration to remove the subnet/interface
! ITDC-NCCO-100 (Catalyst 4506)
!
config term
  no interface Vlan${vlan}
  no ip access-list extended DCACL_VLAN_${vlan}_IN
  no ip access-list extended DCACL_VLAN_${vlan}_OUT
!
router ospf ${ospfinst} vrf ${vrf}
  no network ${snip} ${wc} area ${ospfarea}
end

wr mem
! Be sure to trigger a backup: /local/aclmgr/bin/trigger itdc-ncco-001

EOCONF

    $html->EndBlockTable();
    $html->EndMailWrapper();

}

$html->PageFooter();
