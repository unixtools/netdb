#!/usr/bin/perl

# Begin-Doc
# Name: gen-trigger-sql.pl
# Description: utility to generate sql for triggers, only used interactively when changing schema
# End-Doc

use strict;

my @tables = qw(
    dns_a
    dns_cname
    dns_ptr
    dns_mx
    dns_txt
    dns_aaaa
    dns_ns
    dns_srv
);

print "delimiter /\n";

foreach my $table (@tables) {
    print <<EOSQL;
drop trigger ${table}_delete /

create trigger ${table}_delete after delete on $table
for each row begin
  update dns_soa set mtime=now(),serial=serial+1 where zone=old.zone;
end;
/

drop trigger ${table}_insert /

create trigger ${table}_insert after insert on $table
for each row begin
  update dns_soa set mtime=now(),serial=serial+1 where zone=new.zone;
end;
/

drop trigger ${table}_update /

create trigger ${table}_update after update on $table
for each row begin
  update dns_soa set mtime=now(),serial=serial+1 where zone=new.zone;
end;
/

EOSQL
}
