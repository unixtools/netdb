#!/usr/bin/perl

# Begin-Doc
# Name: edit-privs.pl
# Type: script
# Description: edit netdb internal user privileges
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use Local::HTMLUtil;
use Local::PrivSys;
use lib "/local/netdb/libs";

require NetMaint::HTML;
require NetMaint::Hosts;
require NetMaint::DHCP;
require NetMaint::ARP;
require NetMaint::DNS;
require NetMaint::Util;
require NetMaint::Access;
require NetMaint::Register;
require NetMaint::Logging;

use Data::Dumper;

&HTMLGetRequest();
&HTMLContentType();

my $html   = new NetMaint::HTML( title => "Edit Access Privileges" );
my $util   = new NetMaint::Util;
my $access = new NetMaint::Access;
my $net    = new NetMaint::Network;
my $dns    = new NetMaint::DNS;
my $log    = new NetMaint::Logging;

$html->PageHeader();
$html->RequirePriv("netdb-admin");

$log->Log();

print "<a href=\"", &HTMLScriptURL, "\">Refresh Listing</a><p/>\n";

my $mode = $rqpairs{mode};
if ( $mode eq "delete" ) {
    my $id = $rqpairs{id};
    $access->DeleteRule($id);

    print "<h3>Rule ID <tt>$id</tt> removed.</h3>\n";

    $log->Log();
}
elsif ( $mode eq "add" ) {
    my $who     = $rqpairs{who};
    my $types   = $rqpairs{types};
    my $domains = $rqpairs{domains};
    my $subnets = $rqpairs{subnets};
    my $flags   = $rqpairs{flags};
    my $actions = $rqpairs{actions};

    $who     =~ s/[,\s]+/,/gio;
    $types   =~ s/[,\s]+/,/gio;
    $domains =~ s/[,\s]+/,/gio;
    $subnets =~ s/[,\s]+/,/gio;
    $flags   =~ s/[,\s]+/,/gio;
    $actions =~ s/[,\s]+/,/gio;

    if ( $types   =~ /\*/ ) { $types   = "*"; }
    if ( $domains =~ /\*/ ) { $domains = "*"; }
    if ( $subnets =~ /\*/ ) { $subnets = "*"; }
    if ( $flags   =~ /\*/ ) { $flags   = "*"; }
    if ( $actions =~ /\*/ ) { $actions = "*"; }

    if ( $who eq "" || $who eq "," ) {
        print "<h3>Must specify user list.</h3>\n";
    }
    else {
        $access->AddRule(
            who     => $who,
            types   => $types,
            domains => $domains,
            subnets => $subnets,
            flags   => $flags,
            actions => $actions,
        );

        print "<h3>Rule added.</h3>\n";
    }
}

print "<p/>\n";

if ( $rqpairs{mode} eq "" ) {
    $html->StartMailWrapper("Existing Access Rules");
}

$html->StartBlockTable( "Existing Access Rules", 700 );
$html->StartInnerTable( "Rule ID", "Who", "Types", "Domains", "Subnets", "Flags", "Actions" );

my $info = $access->GetAllRules();
foreach my $id ( sort { $a <=> $b } ( keys(%$info) ) ) {
    $html->StartInnerRow();
    print "<td><font size=-1>$id - <a href=\"", &HTMLScriptURL, "?mode=delete&id=$id\">Delete</a></td>\n";

    my $who     = $info->{$id}->{who}     || "&nbsp;";
    my $types   = $info->{$id}->{types}   || "&nbsp;";
    my $domains = $info->{$id}->{domains} || "&nbsp;";
    my $subnets = $info->{$id}->{subnets} || "&nbsp;";
    my $flags   = $info->{$id}->{flags}   || "&nbsp;";
    my $actions = $info->{$id}->{actions} || "&nbsp;";

    $who     =~ s|,|<br/>\n|gio;
    $types   =~ s|,|<br/>\n|gio;
    $domains =~ s|,|<br/>\n|gio;
    $subnets =~ s|,|<br/>\n|gio;
    $flags   =~ s|,|<br/>\n|gio;
    $actions =~ s|,|<br/>\n|gio;

    print "<td align=center><font size=-1><tt>$who</td>\n";
    print "<td align=center><font size=-1><tt>$types</td>\n";
    print "<td align=center><font size=-1><tt>$domains</td>\n";
    print "<td align=center><font size=-1><tt>$subnets</td>\n";
    print "<td align=center><font size=-1><tt>$flags</td>\n";
    print "<td align=center><font size=-1><tt>$actions</td>\n";

    $html->EndInnerRow();
}
$html->EndInnerTable();
$html->EndBlockTable();

if ( $rqpairs{mode} eq "" ) {
    $html->EndMailWrapper();
}

print "<p/>\n";

&HTMLStartForm(&HTMLScriptURL);
&HTMLHidden( "mode", "add" );

$html->StartBlockTable( "Add New Access Rule", 700 );
$html->StartInnerTable();

$html->StartInnerRow();
print "<td colspan=5 align=center>\n";
print "<b>Users/NetGroups</b> (comma or space separated):<br/>\n";
&HTMLInputText( "who", 80 );
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td align=center valign=top><b>Types:</b><br/>";
&HTMLStartSelect( "types", 10, 1 );
print "<option value=\"\">none\n";
print "<option>*\n";
print "<option>device\n";
print "<option>server\n";
print "<option>cname\n";
&HTMLEndSelect();
print "</td>\n";

print "<td align=center valign=top><b>Domains:</b><br/>";
&HTMLStartSelect( "domains", 10, 1 );
my %domains = $dns->GetDomains();
print "<option value=\"\">none\n";
print "<option>*\n";
foreach my $domain ( sort( keys(%domains) ) ) {
    print "<option>$domain\n";
}
&HTMLEndSelect();
print "</td>\n";

print "<td align=center valign=top><b>Subnets:</b><br/>";
&HTMLStartSelect( "subnets", 10, 1 );
print "<option value=\"\">none\n";
print "<option>*\n";
my $subnets = $net->GetSubnets();
my @subnets = $net->NetworkSort( keys(%$subnets) );
foreach my $subnet (@subnets) {
    print "<option>$subnet\n";
}
&HTMLEndSelect();
print "</td>\n";

print "<td align=center valign=top><b>Special Access Flags:</b><br/>";
&HTMLStartSelect( "flags", 10, 1 );
print "<option value=\"\">none\n";
print "<option>*\n";
print "<option value=ownername>ownername - r##owner.domain\n";
print "<option value=customname>customname - oneword.domain\n";
&HTMLEndSelect();
print "</td>\n";

print "<td align=center valign=top><b>Actions:</b><br/>";
&HTMLStartSelect( "actions", 10, 1 );
print "<option value=\"\">none\n";
print "<option>*\n";
print "<option>view\n";
print "<option>insert\n";
print "<option>delete\n";
print "<option>update\n";
&HTMLEndSelect();
print "</td>\n";
$html->EndInnerRow();

$html->StartInnerRow();
print "<td colspan=5 align=center>\n";
&HTMLSubmit("Add Access");
print " ";
&HTMLReset();
print "</td>\n";
$html->EndInnerRow();
$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();

