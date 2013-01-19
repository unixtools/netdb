#!/usr/bin/perl

# Begin-Doc
# Name: build-switch-vlan-list.pl
# Type: script
# Description: scan network switches to determine list of vlans on each device
# End-Doc

$| = 1;
use lib "/local/umrperl/libs";
use UMR::OracleObject;
use SNMP::Info;
use UMR::SysProg::SetUID;
use Socket;

use lib "/local/netdb/libs";
use NetMaint::DB;
use NetMaint::DHCP;

use strict;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";

my $tmpfile = "/local/netdb/tmp/ip-list." . $$ . "." . time;
unlink($tmpfile);

print "Building list of candidate addresses:\n";
my $dhcp  = new NetMaint::DHCP;
my $addrs = $dhcp->SearchByAdminOption("DOES_MACBLOCK");

open( my $tmph, ">$tmpfile" );
my %seen;
my %addr_to_name;
foreach my $name ( sort @$addrs ) {
    next if ( $name =~ /lwapp/ );    # skip lightweight access points
    next if ( $seen{$name} );

    next if ( $ARGV[0] && index( $name, $ARGV[0] ) < 0 );

    my $packed_ip = gethostbyname($name);
    my $addr;
    if ( !$packed_ip ) {
        print "Unable to look up IP address for $name.\n";
        next;
    }
    else {
        $addr = inet_ntoa($packed_ip);
        print $tmph $addr, "\n";
        print " $name => $addr\n";

        $addr_to_name{$addr} = $name;
    }

    $seen{$name} = 1;
}
close($tmph);
print "Done building ip list.\n";

my $delqry = "delete from switch_vlans where switch=?";
my $delcid = $db->SQL_OpenBoundQuery($delqry)
    || $db->SQL_Error($delqry) && die;

my $insqry = "insert into switch_vlans (switch,tstamp,snmpver,vlan) values (?,now(),?,?)";
my $inscid = $db->SQL_OpenBoundQuery($insqry)
    || $db->SQL_Error($insqry) && die;

open( my $fping, "/usr/sbin/fping -a < $tmpfile; rm -f $tmpfile|" );
while ( chomp( my $addr = <$fping> ) ) {

    my $info;
    my $info2;
    my %seen_macs = ();

    my $version = 1;

    my $name  = $addr_to_name{$addr};
    my $label = "$name/$addr";

    my $community = "monitor";

    print "$label: checking device at version 1\n";
    eval {
        $info = new SNMP::Info(
            AutoSpecify => 1,
            Debug       => 0,
            DestHost    => $addr,
            Community   => "$community",
            Version     => 1,
        );
    };

    if ( !$info ) {
        print "$label: failed at snmp version 1 ($@)\n";
        next;
    }

    my $class;
    eval { $class = $info->class(); };
    if ( !$class ) {
        print "$label: unable to determine class, skipping.\n";
        next;
    }
    print "$label: class: $class\n";

    if ( $class =~ /::C1900/o ) {
        print "$label: skipping snmp v2 check\n";
    }
    else {
        print "$label: checking device at version 2\n";

        eval {
            $info2 = new SNMP::Info(
                AutoSpecify => 1,
                Debug       => 0,
                DestHost    => $addr,
                Community   => "$community",
                Version     => 1,
            );
        };
        if ( !$info ) {
            print "$label: failed at snmp version 2 ($@)\n";
        }
        else {
            $version = 2;
            $info    = $info2;
        }
    }

    print "$label: fetching vlan list\n";
    my $vids  = $info->v_name();
    my %vlans = ();
    foreach my $vid ( keys(%$vids) ) {
        my $vlan = $vid;
        my $name = $vids->{$vid};
        $vlan =~ s/^1\.//o;

        next if ( $name =~ /-default/ );
        next if ( $name eq "default" );

        $vlans{$vlan} = 1;
    }

    $db->SQL_ExecQuery( $delcid, $name );

    print "$label: Adding with snmp version $version and null vlan to scan table.\n";
    $db->SQL_ExecQuery( $inscid, $name, $version, '' )
        || $db->SQL_Error( $insqry . " $name / $version / ''" ) && next;

    foreach my $vlan ( sort { $a <=> $b } keys(%vlans) ) {
        print "$label: Adding $vlan / $version to scan table.\n";
        $db->SQL_ExecQuery( $inscid, $name, $version, $vlan )
            || $db->SQL_Error( $insqry . " $name / $version / $vlan" ) && next;
    }

}
close($fping);
unlink($tmpfile);

$db->SQL_CloseQuery($inscid);
$db->SQL_CloseQuery($delcid);

my $qry = "delete from switch_vlans where tstamp < date_sub(now(),interval 1 day)";
$db->SQL_ExecQuery($qry) || $db->SQL_Error($qry);
