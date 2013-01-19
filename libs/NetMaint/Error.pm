# Begin-Doc
# Name: NetMaint::Error
# Type: module
# Description: Common error handling/reporting routines
# Comments: Module should be standalone and not use the HTML object.
# Comments: Module is a singleton - state is shared across all objects.
# End-Doc

package NetMaint::Error;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use UMR::Error;

@ISA    = qw(Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::Error()
# End-Doc
sub new {
    return new UMR::Error();
}

1;
