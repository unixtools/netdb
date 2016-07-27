#!/usr/bin/perl

# Begin-Doc
# Name: load.pl
# Type: script
# Description: loads json schema in metadata_fields from config files if they have changed
# End-Doc

use strict;

BEGIN { do "/local/netdb/libs/init.pl"; }

use Local::SetUID;

use NetMaint::DB;
use JSON;

&SetUID("netdb");

my $db = new NetMaint::DB() || die "failed to open db!";
my $json = new JSON;
$json->canonical(1);

my $force = 0;
if ( $ARGV[0] eq "--force" ) {
    $force = 1;
}

my $qry = "select field,jsonschema from metadata_fields order by field";
my $cid = $db->SQL_OpenQuery($qry) || $db->SQL_Error($qry) && die;
my $cnt = 0;
while ( my ( $field, $schemajson ) = $db->SQL_FetchRow($cid) ) {
    if ( $cnt++ ) {
        print "\n";
    }
    my $schema_have;
    eval { $schema_have = decode_json($schemajson); };
    if ($@) {
        print "$field: failed parse of existing ($@)\n";
        $schema_have = {};
    }
    else {
        print "$field: parsed existing schema from db\n";
    }

    if ( -e "./$field.json" ) {
        open( my $in, "<", "./${field}.json" );
        my $wantjson = join( "", <$in> );
        close($in);

        my $schema_want;
        eval { $schema_want = decode_json($wantjson); };
        if ($@) {
            print "$field: failed parse of new schema ($@)\n";
            next;
        }

        my $have = $json->encode($schema_have);
        my $want = $json->encode($schema_want);
        if ( $have ne $want || $force ) {
            print "$field: need to update schema in db\n";
            if ($force) {
                print "  forced update\n";
            }
            else {
                print "   have: $have\n";
                print "   want: $want\n";
            }

            my $uqry = "update metadata_fields set jsonschema=? where field=?";
            $db->SQL_ExecQuery( $uqry, $want, $field ) || $db->SQL_Error( $qry . " ($field)" );
        }
    }
    else {
        print "$field: no json config found.\n";
    }

}
