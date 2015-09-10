use lib "/local/perllib/libs";
use lib "/local/netdb/libs";

if ( -e "/local/netdb/libs/siteinit.pl" ) {
    do "/local/netdb/libs/siteinit.pl";
}

1;