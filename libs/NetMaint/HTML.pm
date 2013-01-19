# Begin-Doc
# Name: NetMaint::HTML
# Type: module
# Description: HTML output routines for netmaint tools
# End-Doc

package NetMaint::HTML;
require 5.000;
require Exporter;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Local::HTMLUtil;
use NetMaint::Util;
use Data::Dumper;
use NetMaint::Leases;
use NetMaint::DHCP;
use Spirent::AppTemplate;
use Local::HTMLImpersonate;

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
    $title = "NetDB: " . $title;


    &HTMLImpersonate("netdb-admin");

    $tmp = new Spirent::AppTemplate(
        title => $title,
        style => <<EOSTYLE,
#content { font-size: 12px; 
}
td { font-size: 12px; font-family: arial; }
th { font-size: 12px; font-family: arial; }
EOSTYLE

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
    print "Before using this application, you must familiarized yourself with the usage\n";
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

    my $ads = new Local::ADSObject( use_gc => 1 );
    my $info = $ads->GetAttributes($userid);
    if ($info) {
        my ( $name, $dn, $address, $title, $department, $phone, $email );

        eval { ($name)       = @{ $info->{displayName} }; };
        eval { ($dn)         = @{ $info->{distinguishedName} }; };
        eval { ($address)    = @{ $info->{streetAddress} }; };
        eval { ($title)      = @{ $info->{title} }; };
        eval { ($department) = @{ $info->{department} }; };
        eval { ($phone)      = @{ $info->{telephoneNumber} }; };
        eval { ($email)      = @{ $info->{mail} }; };

        $self->StartInnerRow();
        print "<td><b>User Type:</td><td>";
        if ( $dn =~ /Staff/ ) {
            print "Faculty/Staff";
        }
        elsif ( $dn =~ /Student/ ) {
            print "Student";
        }
        elsif ( $dn =~ /Courtesy/ ) {
            print "Courtesy";
        }
        elsif ( $dn =~ /Resource/ ) {
            print "Resource";
        }
        elsif ( $dn =~ /Services/ ) {
            print "Service";
        }
        else { print "Unknown"; }
        print "</td>\n";
        $self->EndInnerRow();

        $self->StartInnerRow();
        print "<td><b>Name:</td><td>", $self->Encode($name), "</td>\n";
        $self->EndInnerRow();

        $self->StartInnerRow();
        print "<td><b>Department:</td><td>", $self->Encode($department), "</td>\n";
        $self->EndInnerRow();

        $self->StartInnerRow();
        print "<td><b>Address:</td><td>", $self->Encode($address), "</td>\n";
        $self->EndInnerRow();

        $self->StartInnerRow();
        print "<td><b>Title:</td><td>", $self->Encode($title), "</td>\n";
        $self->EndInnerRow();

        if ( $phone =~ /^(\d{3})(\d{3})(\d{4})$/o ) {
            $phone = "($1) $2-$3";
        }

        $self->StartInnerRow();
        print "<td><b>Phone:</td><td>", $self->Encode($phone), "</td>\n";
        $self->EndInnerRow();

        $self->StartInnerRow();
        print "<td><b>EMail:</td><td>", "<a href=\"mailto:";
        print $self->Encode($email), "\">";
        print $self->Encode($email), "</td>\n";
        $self->EndInnerRow();
    }
    else {
        $self->StartInnerRow();
        print "<td colspan=2>User information not found.</td>\n";
        $self->EndInnerRow();
    }

    $self->EndInnerTable();
    $self->EndBlockTable();
}

# Begin-Doc
# Name: Display_ARP_History
# Type: method
# Description: displays arp history
# Syntax: $obj->Display_ARP_History(title => $title, entries => $entries);
# End-Doc
sub Display_ARP_History {
    my $self    = shift;
    my %opts    = @_;
    my $title   = $opts{title} || "ARP History";
    my $entries = $opts{entries} || return;
    my $util    = $self->{util};

    $self->StartBlockTable( $title, 750 );
    $self->StartInnerTable( "Time", "Ether", "IP", "Router" );

    my $cnt = 0;
    foreach my $entry ( reverse @{$entries} ) {
        $self->StartInnerRow();
        print "<td><tt>", $entry->{tstamp}, "</tt></td>\n";
        print "<td><tt>", $self->SearchLink_Ether( $entry->{ether} ), "</tt></td>\n";
        print "<td><tt>", $self->SearchLink_IP( $entry->{ip} ),       "</tt></td>\n";

        my $rname = $util->ResolveIP( $entry->{router} );

        print "<td><tt>", $entry->{router}, " ($rname)</tt></td>\n";
        $self->EndInnerRow();
        $cnt++;
    }
    if ( $cnt == 0 ) {
        $self->StartInnerRow();
        print "<td colspan=5 align=center>No history found.</td>\n";
        $self->EndInnerRow();
    }
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
                && $entry->{ip}      eq $last_ip
                && $entry->{server}  eq $last_server
                && $entry->{gateway} eq $last_gateway
                && $entry->{ether}   eq $last_ether );
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
        print $mailtofh "From: Network Management Tool <netdb\@spirenteng.com>\n";
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

1;

