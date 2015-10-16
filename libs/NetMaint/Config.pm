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

our $NETDB_TITLE_PREFIX = "SpirentEng NetDB";

our $NETDB_PRIV_DEFAULT = "netmgr-user";
our $NETDB_PRIV_ADMIN   = "netmgr-admin";
our $NETDB_PRIV_REPORTS = "netmgr-user";

our $NETDB_DEFAULT_TTL = 120;

our $NETDB_MAIL_FROM      = "netdb\@spirenteng.com";
our $NETDB_DEFAULT_NOTIFY = "nneul\@neulinger.org";

our $NETDB_DB_HOST      = "netmgr.spirenteng.com";
our $NETDB_DNS_SERVERS  = ["netmgr.spirenteng.com"];
# Why is this not pulling from database?!
our $NETDB_DHCP_SERVERS = [ "ub-dhcp1-ito.spirenteng.com", "ub-dhcp2-ito.spirenteng.com" ];

our $NETDB_DISABLE_BACKLOG_REPORT = 1;

# Retain dhcp dns entries for this many seconds after release - to handle common case of
# release,reboot,renew-with-same-ip without introducing an annoying cached NXDomain response
our $NETDB_DHCP_HOLDOVER = 600;

sub SearchLink_AnalyzeUser
{
    my $userid = shift;

    # This isn't valid at the moment
    return "<a href=\"https://crowd.spirenteng.com/crowd/console/secure/user/view!default.action?directoryID=1310721&name=${userid}\">" . "(Crowd User Info)</a></td>\n";
}

1;
