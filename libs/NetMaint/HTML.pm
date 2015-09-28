# Begin-Doc
# Name: NetMaint::HTML
# Type: module
# Description: HTML output routines for netmaint tools
# End-Doc

package NetMaint::HTML;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::UsageLogger;
use Local::HTMLUtil;
use NetMaint::Config;
use NetMaint::Util;
use Data::Dumper;
use NetMaint::Leases;
use NetMaint::DHCP;
use Spirent::AppTemplate;
use Local::HTMLImpersonate;
use JSON;

@ISA    = qw(Spirent::AppTemplate Exporter);
@EXPORT = qw();

# Begin-Doc
# Name: new
# Type: function
# Description: Creates object
# Syntax: $maint = new NetMaint::HTML()
# End-Doc
sub new {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $tmp   = {};
    my %opts  = @_;

    my $title = $opts{title} || "Network Maintenance Tool";
    $title = "SpirentEng NetDB: " . $title;

    &LogAPIUsage();

    &HTMLImpersonate("netmgr-admin");

    $tmp = new Spirent::AppTemplate(
        title => $title,
        style => <<EOSTYLE,
#content { font-size: 12px; 
}
td { font-size: 12px; font-family: arial; }
th { font-size: 12px; font-family: arial; }
.sn_mono {
    font-family: monospace;
}
EOSTYLE
        head_extra => <<EOEXTRA,
<link rel="stylesheet" type="text/css" href="/~netdb/css/jquery.dataTables.css" />
<link rel="stylesheet" type="text/css" href="/~netdb/css/custom.dataTables.css" />
<link rel="stylesheet" type="text/css" href="/~netdb/js/jquery-ui-themes/themes/smoothness/jquery-ui.css" />
<script type="text/javascript" language="javascript" src="/~netdb/js/jquery.min.js"></script>
<script type="text/javascript" language="javascript" src="/~netdb/js/jquery-ui/jquery-ui.min.js"></script>
<script type="text/javascript" language="javascript" src="/~netdb/js/DataTables/media/js/jquery.dataTables.min.js"></script>
<script type="text/javascript" language="javascript" src="/~netdb/subnet-sort.js"></script>
EOEXTRA
    );

    $tmp->{util}    = new NetMaint::Util;
    $tmp->{leases}  = new NetMaint::Leases;
    $tmp->{dhcp}    = new NetMaint::DHCP;
    $tmp->{tmpfile} = "";

    return bless $tmp, $class;
}

# Begin-Doc
# Name: PageHeader
# Type: method
# Description: outputs a page header
# Syntax: $obj->PageHeader()
# End-Doc
sub PageHeader {
    my $self = shift;
    my %opts = @_;

    $self->SUPER::PageHeader(@_);

    print "<table border=0 cellpadding=0 cellspacing=0 width=750>\n";

    if ( $0 !~ /menu.pl/o ) {
        print "<tr><td align=center colspan=2>\n";
        print "<a href=\"/auth-cgi-bin/cgiwrap/netdb/menu.pl\">Main Menu</a>\n";
        print " - ";
        print "<a href=\"/auth-cgi-bin/cgiwrap/netdb/search-hosts.pl\">Search Hosts</a>\n";
        print " - ";
        print "<a href=\"/auth-cgi-bin/cgiwrap/netdb/create-host.pl\">Create Host</a>\n";
        print " - ";
        print "<a href=\"/auth-cgi-bin/cgiwrap/netdb/edit-host.pl\">Edit Host</a>\n";
        print " - ";
        print "<a href=\"/auth-cgi-bin/cgiwrap/netdb/net-map.pl\">DNS/IP Listing</a>\n";
        print " - ";
        print "<a href=\"/vm-map.html\">VM Listing</a>\n";
        print "</td></tr>\n";

        print "<tr><td align=center colspan=2><hr></td></tr>\n";
    }

    print "<tr><td align=center colspan=2>\n";
}

# Begin-Doc
# Name: PageFooter
# Type: method
# Description: outputs a page footer
# Syntax: $obj->PageFooter();
# End-Doc
sub PageFooter {
    my $self   = shift;
    my $leases = $self->{leases};

    print "</td></tr>\n";
    print "<tr><td align=center colspan=2><hr></td></tr>\n";

    print "<tr><td align=center colspan=2><font face=arial size=-1>";
    print "Before using this application, you must familiarize yourself with the usage\n";
    print "documentation in the <a href=\"https://origin.spirenteng.com/display/ENGOP/NetDB\">NetDB</a> origin page.\n";
    print "</td></tr>\n";

    print "<tr><td align=center colspan=2><hr></td></tr>\n";
    print "</table>\n";

    $self->SUPER::PageFooter(@_);
}

# Begin-Doc
# Name: Display_HostInfo
# Type: method
# Description: displays host information returned by NetMaint::Hosts::GetHostInfo
# Syntax: $obj->Display_HostInfo($hinfo);
# End-Doc
sub Display_HostInfo {
    my $self  = shift;
    my $hinfo = shift;

    $self->StartBlockTable( "Host Information", 500 );
    $self->StartInnerTable();

    $self->StartInnerRow();
    if ( $0 =~ /view-host/o ) {
        print "<td><b>Full Host Name:</b></td><td>", $self->SearchLink_HostEdit( $hinfo->{host} ), "</td>\n";
    }
    else {
        print "<td><b>Full Host Name:</b></td><td>", $self->SearchLink_Host( $hinfo->{host} ), "</td>\n";
    }
    $self->EndInnerRow();

    $self->StartInnerRow();
    print "<td><b>Host Domain:</b></td><td>", $hinfo->{domain}, "</td>\n";
    $self->EndInnerRow();

    $self->StartInnerRow();
    print "<td><b>Registration Type:</b></td><td>", $hinfo->{type}, "</td>\n";
    $self->EndInnerRow();

    $self->StartInnerRow();
    print "<td><b>Owner UserID:</b></td><td>", $hinfo->{owner};
    print " ";
    print $self->SearchLink_AnalyzeUser( $hinfo->{owner} );
    print "</td>\n";
    $self->EndInnerRow();

    $self->StartInnerRow();
    print "<td><b>Created:</b></td><td>", $hinfo->{ctime}, "</td>\n";
    $self->EndInnerRow();

    $self->StartInnerRow();
    print "<td><b>Last Modified:</b></td><td>", $hinfo->{mtime}, " by ", $hinfo->{modifiedby};
    print " ";
    print $self->SearchLink_AnalyzeUser( $hinfo->{modifiedby} );
    print "</td>\n";
    $self->EndInnerRow();

    if ( $hinfo->{description} ) {
        $self->StartInnerRow();
        print "<td><b>Description:</b></td><td>", $self->Encode( $hinfo->{description} ), "</td>\n";
        $self->EndInnerRow();
    }

    if ( $hinfo->{location} ) {
        $self->StartInnerRow();
        print "<td><b>Location:</b></td><td>", $self->Encode( $hinfo->{location} ), "</td>\n";
        $self->EndInnerRow();
    }

    if ( $hinfo->{admin_comments} ) {
        $self->StartInnerRow();
        print "<td><b>Admin Comments:</b></td><td>", $self->Encode( $hinfo->{admin_comments} ), "</td>\n";
        $self->EndInnerRow();
    }

    $self->StartInnerRow();
    print "<td><b>Host Expiration Date:</b></td><td>";
    if ( $hinfo->{purge_date} ) {
        print $hinfo->{purge_date};
        if ( $hinfo->{purge_date_updated} ) {
            print " as of ", $hinfo->{purge_date_updated};
        }
        else {
            print " as of last calculation.";
        }
    }
    else {
        print "Not yet determined.\n";
    }
    print "</td>\n";
    $self->EndInnerRow();

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_CIRT_Info
# Type: method
# Description: displays cirt information returned by NetMaint::Hosts::GetHostInfo
# Syntax: $obj->Display_CIRT_Info($hinfo);
# End-Doc
sub Display_CIRT_Info {
    my $self  = shift;
    my $hinfo = shift;

    $self->StartBlockTable( "CIRT Classification Information", 500 );
    $self->StartInnerTable();

    $self->StartInnerRow();
    print "<td><b>Class:</b></td><td>", $self->SearchLink_Host( $hinfo->{cirt_class} ), "</td>\n";
    print "<td><b>Device Type:</b></td><td>", $hinfo->{cirt_type}, "</td>\n";
    $self->EndInnerRow();

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_Person
# Type: method
# Description: displays info for a person
# Syntax: $obj->Display_Person(title => $title, userid => $userid);
# End-Doc
sub Display_Person {
    my $self   = shift;
    my %opts   = @_;
    my $title  = $opts{title} || "Person Details";
    my $userid = $opts{userid} || return;

    $self->StartBlockTable( $title, 500 );
    $self->StartInnerTable();

    $self->StartInnerRow();
    print "<td><b>UserID:</td><td>", $userid;
    print " ";
    print $self->SearchLink_AnalyzeUser($userid);
    print "</td>\n";
    $self->EndInnerRow();

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_DHCP_History
# Type: method
# Description: displays dhcp history
# Syntax: $obj->Display_DHCP_History(title => $title, entries => $entries);
# End-Doc
sub Display_DHCP_History {
    my $self     = shift;
    my %opts     = @_;
    my $title    = $opts{title} || "DHCP History";
    my $entries  = $opts{entries} || return;
    my $condense = $opts{condense};
    my $util     = $self->{util};

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Time", "Ether", "Type", "IP", "Server", "Gateway" );

    my ( $last_ether, $last_type, $last_server, $last_gateway, $last_ip );

    my $cnt = 0;
    foreach my $entry ( reverse @{$entries} ) {
        if ($condense) {
            next
                if ( $entry->{type} eq $last_type
                && $entry->{ip} eq $last_ip
                && $entry->{server} eq $last_server
                && $entry->{gateway} eq $last_gateway
                && $entry->{ether} eq $last_ether );
            next
                if ( $entry->{gateway} eq "eth0"
                && $last_gateway =~ /\.1$/o );
            next
                if ( $entry->{gateway} eq "0"
                && $last_gateway =~ /\.1$/o );
            next
                if ( $last_gateway eq "eth0"
                && $entry->{gateway} =~ /\.1$/o );
            next
                if ( $last_gateway eq "0"
                && $entry->{gateway} =~ /\.1$/o );
        }

        my $printserver = $entry->{server};

        $self->StartInnerRow();
        print "<td><tt>", $entry->{tstamp}, "</td>\n";
        print "<td><tt>", $self->SearchLink_Ether( $entry->{ether} ), "</td>\n";
        print "<td><tt>", $entry->{type}, "</td>\n";
        print "<td><tt>", $entry->{ip},   "</td>\n";
        print "<td><tt>", $printserver, "</td>\n";
        print "<td><tt>", $entry->{gateway}, "</td>\n";
        $self->EndInnerRow();

        $last_type    = $entry->{type};
        $last_ip      = $entry->{ip};
        $last_server  = $entry->{server};
        $last_gateway = $entry->{gateway};
        $last_ether   = $entry->{ether};

        $cnt++;
    }
    if ( $cnt == 0 ) {
        $self->StartInnerRow();
        print "<td colspan=6 align=center>No history found.</td>\n";
        $self->EndInnerRow();
    }
    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_DHCP_Host_Options
# Type: method
# Description: displays dhcp host options
# Syntax: $obj->Display_DHCP_Host_Options(title => $title, options => $options);
# End-Doc
sub Display_DHCP_Host_Options {
    my $self    = shift;
    my %opts    = @_;
    my $title   = $opts{title} || "DHCP Host Options";
    my $options = $opts{options} || return;
    my $util    = $self->{util};

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Last Modified", "Option" );

    foreach my $entry ( reverse @{$options} ) {
        $self->StartInnerRow();
        print "<td><tt>", $entry->{tstamp}, "</td>\n";
        print "<td><tt>", $self->Encode( $entry->{option} ), "</td>\n";
        $self->EndInnerRow();
    }
    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_Admin_Host_Options
# Type: method
# Description: displays dhcp host options
# Syntax: $obj->Display_Admin_Host_Options(title => $title, options => $options);
# End-Doc
sub Display_Admin_Host_Options {
    my $self    = shift;
    my %opts    = @_;
    my $title   = $opts{title} || "Admin Host Options";
    my $options = $opts{options} || return;
    my $util    = $self->{util};

    my @tmp = @{$options};
    return if ( $#tmp < 0 );

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Last Modified", "Option" );

    foreach my $entry ( reverse @{$options} ) {
        $self->StartInnerRow();
        print "<td><tt>", $entry->{tstamp}, "</td>\n";
        print "<td><tt>", $self->Encode( $entry->{option} ), "</td>\n";
        $self->EndInnerRow();
    }
    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_A_Records
# Type: method
# Description: displays dns A records
# Syntax: $obj->Display_A_Records(title => $title, records => $records);
# End-Doc
sub Display_A_Records {
    my $self    = shift;
    my %opts    = @_;
    my $title   = $opts{title} || "Address Records";
    my $records = $opts{records} || return;

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Zone", "TTL", "Name", "Address", "Modified", "Created", "Dynamic" );

    foreach my $entry ( @{$records} ) {
        $self->StartInnerRow();
        print "<td><tt>", $entry->{zone}, "</td>\n";
        print "<td><tt>", $entry->{ttl} ? $entry->{ttl} : "Default", "</td>\n";
        print "<td><tt>", $self->SearchLink_Host( $entry->{name} ),  "</td>\n";
        print "<td><tt>", $self->SearchLink_IP( $entry->{address} ), "</td>\n";
        print "<td><tt>", $entry->{mtime}, "</td>\n";
        print "<td><tt>", $entry->{ctime}, "</td>\n";
        print "<td><tt>", $entry->{dynamic} ? "Yes" : "No", "</td>\n";
        $self->EndInnerRow();
    }
    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_MProbe_Info
# Type: method
# Description: displays links to relevant micro probes
# Syntax: $obj->Display_MProbe_Info(title => $title, info => $info);
# End-Doc
sub Display_MProbe_Info {
    my $self  = shift;
    my %opts  = @_;
    my $title = $opts{title} || "Micro Probe Information";
    my $info  = $opts{info} || return;
    my $util  = $self->{util};

    my @tmp = keys %{$info};
    return if ( $#tmp < 0 );

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "IP", "Probe Links" );

    foreach my $ip ( sort keys %{$info} ) {
        my @probes = sort( @{ $info->{$ip} } );
        $self->StartInnerRow();
        print "<td><tt>", $ip, "</td>\n";
        print "<td><tt>", join( ", ", @probes ), "</td>\n";
        $self->EndInnerRow();
    }

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_MX_Records
# Type: method
# Description: displays dns MX records
# Syntax: $obj->Display_MX_Records(title => $title, records => $records);
# End-Doc
sub Display_MX_Records {
    my $self    = shift;
    my %opts    = @_;
    my $title   = $opts{title} || "Mail Exchanger Records";
    my $records = $opts{records} || return;

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Zone", "TTL", "Name", "Priority", "Address", "Modified", "Created", "Dynamic" );

    foreach my $entry ( @{$records} ) {
        $self->StartInnerRow();
        print "<td><tt>", $entry->{zone}, "</td>\n";
        print "<td><tt>", $entry->{ttl} ? $entry->{ttl} : "Default", "</td>\n";
        print "<td><tt>", $self->SearchLink_Host( $entry->{name} ), "</td>\n";
        print "<td><tt>", $entry->{priority}, "</td>\n";
        print "<td><tt>", $self->SearchLink_Host( $entry->{address} ), "</td>\n";
        print "<td><tt>", $entry->{mtime}, "</td>\n";
        print "<td><tt>", $entry->{ctime}, "</td>\n";
        print "<td><tt>", $entry->{dynamic} ? "Yes" : "No", "</td>\n";
        $self->EndInnerRow();
    }

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_CNAME_Records
# Type: method
# Description: displays dns CNAME records
# Syntax: $obj->Display_CNAME_Records(title => $title, records => $records);
# End-Doc
sub Display_CNAME_Records {
    my $self    = shift;
    my %opts    = @_;
    my $title   = $opts{title} || "Canonical Name Records";
    my $records = $opts{records} || return;

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Zone", "TTL", "Name", "Address", "Modified", "Created", "Dynamic" );

    foreach my $entry ( @{$records} ) {
        $self->StartInnerRow();
        print "<td><tt>", $entry->{zone}, "</td>\n";
        print "<td><tt>", $entry->{ttl} ? $entry->{ttl} : "Default", "</td>\n";
        print "<td><tt>", $self->SearchLink_Host( $entry->{name} ),    "</td>\n";
        print "<td><tt>", $self->SearchLink_Host( $entry->{address} ), "</td>\n";
        print "<td><tt>", $entry->{mtime}, "</td>\n";
        print "<td><tt>", $entry->{ctime}, "</td>\n";
        print "<td><tt>", $entry->{dynamic} ? "Yes" : "No", "</td>\n";
        $self->EndInnerRow();
    }

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: SearchLink_AnalyzeUser
# Type: method
# Description: outputs search link for ethernet addresses
# Syntax: $html = $obj->SearchLink_AnalyzeUser($userid)
# End-Doc
sub SearchLink_AnalyzeUser {
    my $self   = shift;
    my $userid = shift;

    return "<a href=\"https://crowd.spirenteng.com/crowd/console/secure/user/view!default.action?directoryID=1310721&name=${userid}\">"
        . "(Crowd User Info)</a></td>\n";
}

# Begin-Doc
# Name: SearchLink_Ether
# Type: method
# Description: outputs search link for ethernet addresses
# Syntax: $html = $obj->SearchLink_Ether($ether)
# End-Doc
sub SearchLink_Ether {
    my $self       = shift;
    my $ether      = shift;
    my $util       = $self->{util};
    my $shortether = $util->CondenseEther($ether);

    return
        "<a href=\"/auth-cgi-bin/cgiwrap/netdb/search-hosts.pl?mode=byether&search=${shortether}\">"
        . $util->FormatEther($ether) . "</a>";
}

# Begin-Doc
# Name: SearchLink_IP
# Type: method
# Description: outputs search link for ip addresses
# Syntax: $html = $obj->SearchLink_IP($ip)
# End-Doc
sub SearchLink_IP {
    my $self    = shift;
    my $ip      = shift;
    my $util    = $self->{util};
    my $shortip = $util->CondenseIP($ip);

    return "<a href=\"/auth-cgi-bin/cgiwrap/netdb/search-hosts.pl?mode=byip&search=${shortip}\">$ip</a>";
}

# Begin-Doc
# Name: SearchLink_Host
# Type: method
# Description: outputs search link for host name
# Syntax: $html = $obj->SearchLink_Host($host)
# End-Doc
sub SearchLink_Host {
    my $self = shift;
    my $host = lc shift;
    my $util = $self->{util};

    return "<a href=\"/auth-cgi-bin/cgiwrap/netdb/view-host.pl?host=${host}\">${host}</a>";
}

# Begin-Doc
# Name: SearchLink_HostEdit
# Type: method
# Description: outputs edit search link for host name
# Syntax: $html = $obj->SearchLink_HostEdit($host)
# End-Doc
sub SearchLink_HostEdit {
    my $self = shift;
    my $host = lc shift;
    my $util = $self->{util};

    return "<a href=\"/auth-cgi-bin/cgiwrap/netdb/edit-host.pl?mode=view&host=${host}\">${host}</a>";
}

# Begin-Doc
# Name: StartMailWrapper
# Type: method
# Description: output information as needed to generate a mailto wrapper for a report
# Syntax: $obj->StartMailWrapper($subject)
# End-Doc
sub StartMailWrapper {
    my $self  = shift;
    my $title = shift || "Network Tool Output";
    my $util  = $self->{util};

    my $mailto = $main::rqpairs{mailto};
    &HTMLStartForm( &HTMLScriptURL, "GET" );
    while ( my ( $k, $v ) = each %main::rqpairs ) {
        next if ( $k eq "mailto" );
        &HTMLHidden( $k, $v );
    }
    &HTMLSubmit("Mail Output To:");
    print " ";
    &HTMLInputText( "mailto", 30, $main::rqpairs{mailto} );
    &HTMLEndForm;
    print "<p>\n";

    if ($mailto) {
        $mailto =~ s/\s+/,/gio;
        $mailto =~ s/;/,/gio;

        foreach my $email ( split( /\s*,\s*/, $mailto ) ) {
            if (  !$util->UserInfo($email)
                && $email !~ /^[a-z0-9-_.]+\@[a-z0-9-_\.]+$/o )
            {
                $self->ErrorExit("Invalid email address: $email");
            }
        }

        my $mailtofh;

        open( $mailtofh, "|/usr/lib/sendmail -t" );
        print $mailtofh "From: NetDB Tool <$NETDB_MAIL_FROM>\n";
        print $mailtofh "Subject: $title - " . scalar(localtime) . "\n";
        print $mailtofh "Mime-Version: 1.0\n";
        print $mailtofh "Content-type: text/html\n";
        print $mailtofh "To: $mailto\n";
        print $mailtofh "\n\n";

        print "Mailing output to: ", $self->Encode($mailto), "\n<p>\n";

        select($mailtofh);
        $self->{mailtofh} = $mailtofh;

        print "<body>";
    }
}

# Begin-Doc
# Name: EndMailWrapper
# Type: method
# Description: ends mail wrapper for a report
# Syntax: $obj->EndMailWrapper()
# End-Doc
sub EndMailWrapper {
    my $self = shift;

    my $mailto = $main::rqpairs{mailto};
    if ($mailto) {
        print "</body>\n";

        my $mailtofh = $self->{mailtofh};
        close($mailtofh);
        undef( $self->{mailtofh} );

        select(STDOUT);
        print "Output has been mailed.<p>\n";

        &HTMLStartForm( &HTMLScriptURL, "GET" );
        while ( my ( $k, $v ) = each %main::rqpairs ) {
            next if ( $k eq "mailto" );
            &HTMLHidden( $k, $v );
        }
        &HTMLSubmit("View Output");
        &HTMLEndForm;
        print "<p>\n";
    }
}

# Begin-Doc
# Name: StartDTable
# Type: method
# Description: outputs structure for a dynamic table with headers/searches/etc.
# Comments: options id, filter, columns, source, sortable, source_columns, source_columndefs, source_columns_raw,
# source_columndefs_raw, search_cols, paging, height, refresh
# Syntax: $obj->StartDTable(%opts)
# End-Doc
sub StartDTable {
    my $self = shift;

    my %opts               = @_;
    my $id                 = $opts{id};
    my $filter             = $opts{filter};
    my $cols               = $opts{columns};
    my $ajax_source        = $opts{source};
    my $sortable           = $opts{sortable};
    my $source_cols        = $opts{source_columns};
    my $source_coldefs     = $opts{source_columndefs};
    my $source_cols_raw    = $opts{source_columns_raw};
    my $source_coldefs_raw = $opts{source_columndefs_raw};
    my $search_cols        = $opts{search_cols};
    my $paging             = $opts{paging};
    my $height             = $opts{height};
    my $pagesize           = $opts{pagesize};
    my $refresh            = int( $opts{refresh} );
    my $json               = new JSON;
    $json->canonical(1);

    print "<script type=\"text/javascript\" class=\"init\">\n";
    my $qfilter = $self->Encode($filter);

    my $proc = "true";
    if ($refresh) {
        $proc = "false";
    }

    if ( !defined($search_cols) ) {
        $search_cols = 1;
    }

    print <<EOF;

\$(document).ready(function() {
    // Setup - add a text input to each footer cell
    \$('#${id} tfoot th').each( function () {
        var title = \$('#${id} tfoot th').eq( \$(this).index() ).text();
        \$(this).html( '<input type="text" placeholder="Search '+title+'" />' );
    } );
 
    // Default to log msg instead of alert dialog
    \$.fn.dataTableExt.sErrMode = 'throw';

    // DataTable
    var table = \$('#${id}').DataTable({
    // had problems with state save on some firefox versions
    //    "stateSave" : true,
        "deferRender": true,
        "processing" : $proc
EOF
    if ( defined($height) && $height ) {
        print ',"scrollY": "', int($height) . 'px"' . "\n";
    }
    elsif ( defined($height) && !$height ) {
        # zero height requested, ignore
    }
    else {
        print ',"scrollY": "300px"' . "\n";
    }
    if ( defined($sortable) ) {
        print ',"ordering": ' . int($sortable) . "\n";
    }
    if ($ajax_source) {
        print ',"ajax": "' . $ajax_source . '"' . "\n";
    }
    if ($source_coldefs_raw) {
        print ',"columnDefs": ' . $source_coldefs_raw . "\n";
    }
    elsif ($source_coldefs) {
        print ',"columnDefs": ' . $json->pretty->encode($source_coldefs) . "\n";
    }
    if ($source_cols_raw) {
        print ',"columns": ' . $source_cols_raw . "\n";
    }
    elsif ($source_cols) {
        print ',"columns": ' . $json->pretty->encode($source_cols) . "\n";
    }

    if ( defined($paging) && !$paging ) {
        print ',"paging" : false' . "\n";
    }

    if ( defined($pagesize) ) {
        print ',"iDisplayLength" : ' . int($pagesize) . "\n";
    }

    print " });\n";

    if ($qfilter) {
        print "table.search(\"$qfilter\");\n";
    }

    if ($refresh) {
        my $refresh_ms = int($refresh) * 1000;
        print "setInterval( function () { table.ajax.reload(); }, $refresh_ms );\n";
    }

    if ($search_cols) {
        print <<EOF;
 
    // Apply the search
    table.columns().eq( 0 ).each( function ( colIdx ) {
        \$( 'input', table.column( colIdx ).footer() ).on( 'keyup change', function () {
            table
                .column( colIdx )
                .search( this.value )
                .draw();
        } );
    } );
EOF
    }

    print <<EOF;
} );
</script>
EOF

    print "<table id=\"${id}\" class=\"display cell-border compact\" cellspacing=\"0\" width=\"100%\">\n";

    print "<thead>\n";
    print "<tr>\n";
    foreach my $col (@$cols) {
        print "<th>$col</th>\n";
    }
    print "</tr>\n";
    print "</thead>\n";

    if ($search_cols) {
        print "<tfoot>\n";
        print "<tr>\n";
        foreach my $col (@$cols) {
            print "<th>$col</th>\n";
        }
        print "</tr>\n";
        print "</tfoot>\n";
    }

    print "<tbody>\n";
}

# Begin-Doc
# Name: EndDTable
# Type: method
# Description: closes html structure for a dynamic table
# Comments: opts has 'id' field only
# Syntax: $obj->StartDTable(%opts)
# End-Doc
sub EndDTable {
    my $self = shift;
    my %opts = @_;
    my $id   = $opts{id};

    print "</tbody>\n";
    print "</table>\n";

    return if ( !$id );

    print "<script type=\"text/javascript\" class=\"init\">\n";

    print <<EOF;
\$(document).ready(function() {
    \$('#${id}').DataTable().draw();
} );
</script>
EOF

}

1;

