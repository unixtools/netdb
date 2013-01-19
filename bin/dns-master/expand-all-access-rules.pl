#!/usr/bin/perl

# Begin-Doc
# Name: expand-all-access-rules.pl
# Type: script
# Description: update access rules table to account for netgroup membership changes
# End-Doc

use strict;

use lib "/local/perllib/libs";
use lib "/local/spirentlib/libs";
use lib "/local/netdb/libs";
use NetMaint::Access;
use Local::SetUID;

&SetUID("netdb");

my $access = new NetMaint::Access;
my $rules  = $access->GetAllRules();

foreach my $id ( keys(%$rules) ) {
    $access->ExpandRule($id);
}

# Clean out any expanded data that doesn't have a matching rule in rules table
$access->CleanOldData();

