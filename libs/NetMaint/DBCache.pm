# Begin-Doc
# Name: NetMaint::DBCache
# Type: module
# Description: object to manage a shared query cache used by all of the netmaint modules
# End-Doc

package NetMaint::DBCache;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require NetMaint::DB;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: CACHE
# Type: variable
# Description: global CACHE handle for all callers to this api
# Syntax: $CACHE
# End-Doc
our $CACHE;

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::DBCache()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};

    $tmp->{db} = new NetMaint::DB;
    if ( !$CACHE ) {
        $CACHE = {};
    }


    return bless $tmp, $class;
}

# Begin-Doc
# Name: clear
# Type: method
# Description: Clears the query cache
# Syntax: $obj->clear();
# End-Doc
sub clear {
    my $self = shift;
    my $qry  = shift;
    my $db   = $self->{db};

    if ($CACHE) {
        foreach my $cid ( values(%$CACHE) ) {
            $db->SQL_CloseQuery($cid);
        }
    }

    undef $CACHE;
    $CACHE = {};
}

1;

# Begin-Doc
# Name: open
# Type: method
# Description: Returns a cached query cursor
# Syntax: $cid = $obj->open($qry);
# End-Doc
sub open {
    my $self = shift;
    my $qry  = shift;
    my $db   = $self->{db};

    if ( !$db ) {
        return undef;
    }

    if ( $CACHE->{$qry} ) {
        return $CACHE->{$qry};
    }
    else {
        my $cid = $db->SQL_OpenBoundQuery($qry)
            || $db->SQL_Error($qry) && return undef;
        $CACHE->{$qry} = $cid;
        return $cid;
    }
}

1;
