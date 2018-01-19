#
use lib "/local/perllib/libs";
use lib "/local/netdb/libs";

use lib "/local/spirentlib/libs";

use Local::PrivSys;
&PrivSys_InitADS("user" => "svc-auth-ito");

1;
