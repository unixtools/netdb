#!/usr/bin/perl

# Begin-Doc
# Name: duplicate-short-names.pl
# Type: script
# Description: Report on hosts that have conflicting short names
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::HTMLUtil;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::DB;
require NetMaint::Logging;

use UMR::PrivSys;
&PrivSys_RequirePriv("sysprog:netdb:reports");

&HTMLGetRequest();
&HTMLContentType();

my $html = new NetMaint::HTML;
my $log  = new NetMaint::Logging;

$log->Log();

$html->PageHeader( title => "Short Hostname Duplications" );

print "This report indicates any hosts that have potential conflicts with the short hostname of ";
print "another registered host.\n";
print "<p/>\n";

my $db = new NetMaint::DB;

my $qry = "select host from hosts order by host";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

$html->StartMailWrapper("Duplicate Short Hostname");
$html->StartBlockTable("Duplicate Short Hostname");
$html->StartInnerTable( "Host", "Conflicting Hosts" );

my @ok_doms = qw(srv.mst.edu mst.edu);
my $ok_dups;
foreach my $dom1 (@ok_doms) {
    foreach my $dom2 (@ok_doms) {
        $ok_dups->{$dom1}->{$dom2} = 1;
    }
}

my %bad;
my %short;

while ( my ($host) = $db->SQL_FetchRow($cid) ) {

    # Ignore since known case of lots of duplicates
    next if ( $host =~ /files\.mst\.edu$/o );

    my $shost = $host;
    $shost =~ s/\..*//gio;

    if ( $short{$shost} ) {
        my @tmp = @{ $short{$shost} };
    PAIR: foreach my $host2 (@tmp) {
            foreach my $dom1 ( keys %{$ok_dups} ) {
                foreach my $dom2 ( keys %{ $ok_dups->{$dom1} } ) {
                    if (   $host eq "${shost}.${dom1}"
                        && $host2 eq "${shost}.${dom2}" )
                    {
                        next PAIR;
                    }
                }
            }

            $bad{$host}  = 1;
            $bad{$host2} = 1;
        }
    }
    push( @{ $short{$shost} }, $host );
}

foreach my $host ( sort( keys(%bad) ) ) {
    next if ( $host =~ /^www\./o );
    next if ( $host =~ /^_kerberos/o );

    my $shost = $host;
    $shost =~ s/\..*//gio;

    $html->StartInnerRow();
    print "<td>$host</td>\n";

    print "<td>\n";

    foreach my $oldhost ( sort( @{ $short{$shost} } ) ) {
        next if ( $oldhost eq $host );
        print $html->SearchLink_Host($oldhost), "<br/>\n";
    }

    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();
$html->EndMailWrapper();

$html->PageFooter();
