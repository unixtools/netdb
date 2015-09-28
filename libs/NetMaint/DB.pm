# Begin-Doc
# Name: NetMaint::DB
# Type: module
# Description: object to hold database connection for all of the netmaint library routines
# End-Doc

package NetMaint::DB;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::UsageLogger;
use Local::MySQLObject;
use Sys::Hostname;

use NetMaint::Config;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: DB
# Type: variable
# Description: global DB handle for all callers to this api
# Syntax: $DB
# End-Doc
our $DB;

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::DB()
# End-Doc
sub new {
    &LogAPIUsage();

    if ( !$DB ) {
        my $hn = hostname;
        if ( $hn =~ /netmgr/ ) {
            $DB = new Local::MySQLObject;
            $DB->SQL_OpenDatabase( "netdb", user => "netdb" )
                || die "Couldn't open mysql DB!";
        }
        else {
            $DB = new Local::MySQLObject;
            $DB->SQL_OpenDatabase( "netdb", user => "netdb", host => $NETDB_DB_HOST )
                || die "Couldn't open mysql DB!";
        }
    }

    return $DB;
}

# Begin-Doc
# Name: CloseDB
# Type: function
# Description: Closes common DB handle
# Syntax: &NetMaint::DB::CloseDB()
# End-Doc
sub CloseDB {

    # This is ugly
    eval {
        require NetMaint::DBCache;
        my $dbc = new NetMaint::DBCache;
        $dbc->clear();
    };

    if ($DB) {
        $DB->SQL_CloseDatabase();
    }
    undef $DB;
}

1;
