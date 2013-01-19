#!/usr/bin/perl

# Begin-Doc
# Name: export-alm-host-owner.pl
# Type: script
# Description: generate report of host,owner for ALM
# End-Doc

use strict;

use lib "/local/umrperl/libs";
use UMR::OracleObject;
use UMR::SysProg::SetUID;
use UMR::AuthSrv;
use Net::SFTP;

use lib "/local/netdb/libs";
use NetMaint::DB;

$ENV{HOME} = "/local/netdb";

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";

my $tfile = "/local/netdb/tmp/alm-hosts-" . $$ . "." . time . ".csv";
unlink($tfile);

my $qry = "select host,owner from hosts where type in ('desktop','printer')";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;

open( my $out, ">$tfile" );
print $out "hostname,owner\n";

while ( my ( $hn, $own ) = $db->SQL_FetchRow($cid) ) {
    print $out "$hn,$own\n";
}
close($out);

if ( $db->SQL_ErrorCode() ) {
    print "Failed query, not uploading file.\n";
    &done();
}

my $pw = &AuthSrv_Fetch( instance => "ads" );
if ( !$pw ) {
    print "Failed to retrieve pw.\n";
    &done();
}

my $sftp = new Net::SFTP( "minersftp.mst.edu", user => "netdb", password => $pw );
if ( !$sftp ) {
    print "Failed to create sftp session.";
    &done();
}

my $res = $sftp->put( $tfile, "/dfs/applications/ALM/alm-netdb.csv" );
if ($res) {
    print "File uploaded successfully.\n";
}
else {
    print "File upload failed.\n";
}

&done();

# Begin-Doc
# Name: done
# Syntax: &done();
# Description: clean up and terminate
# End-Doc
sub done {
    unlink($tfile);
    exit;
}
