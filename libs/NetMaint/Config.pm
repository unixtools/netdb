# Begin-Doc
# Name: NetMaint::Config
# Type: module
# Description: global config parameters - store centrally
# End-Doc

package NetMaint::Config;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

@ISA    = qw(Exporter);
@EXPORT = qw();

sub import {
    no strict 'refs';

    my $caller = caller;

    while ( my ( $name, $symbol ) = each %{ __PACKAGE__ . '::' } ) {
        next if ( $name !~ /^NETDB_[A-Z_]+/ );
        next unless *{$symbol}{SCALAR};

        my $imported = $caller . '::' . $name;
        *{$imported} = \*{$symbol};
    }
}

our $NETDB_PRIV_DEFAULT = "netmgr-user";
our $NETDB_PRIV_ADMIN   = "netmgr-admin";
our $NETDB_PRIV_REPORTS = "netmgr-user";

our $NETDB_DEFAULT_TTL = 900;

our $NETDB_MAIL_FROM      = "netdb\@spirenteng.com";
our $NETDB_DEFAULT_NOTIFY = "nneul\@neulinger.org";

our $NETDB_DB_HOST      = "netmgr.spirenteng.com";
our $NETDB_DNS_SERVERS  = ["netmgr.spirenteng.com"];
our $NETDB_DHCP_SERVERS = [ "fc-dhcp-ito.spirenteng.com", "fc-dhcp-ent.spirenteng.com" ];

our $NETDB_DISABLE_BACKLOG_REPORT = 1;

1;
