#!/usr/bin/perl

# Begin-Doc
# Name: archive-dhcp-config.pl
# Type: script
# Description: save a dated copy of the most recently built dhcp configuration
# End-Doc

use strict;

my $archdir = "/local/config/data-archive";
my $srcdir  = "/local/config/data";

my ( $base, $yday, $dir, $offset );
$offset = 0 * 24 * 60 * 60;
$base   = time + $offset;

my @tmp = localtime($base);
$yday = $tmp[7];
my $tstamp = sprintf( "%.4d-%.2d-%.2d-%.2d%.2d%.2d", $tmp[5] + 1900, $tmp[4] + 1, $tmp[3], $tmp[2], $tmp[1], $tmp[0] );

my $dir = "every-" . ( ( time % 10 ) + 1 );
if ( $tmp[1] == 0 ) {
    $dir = "hourly-" . ( ( $tmp[2] % 5 ) + 1 );
}
if ( $tmp[1] == 0 && $tmp[2] == 12 ) {
    $dir = "daily-" . ( ( $yday % 5 ) + 1 );
}
if ( $tmp[1] == 0 && $tmp[2] == 12 && $yday % 7 == 0 ) {
    $dir = "weekly-" . ( ( $yday % 3 ) + 1 );
}

print "Archiving data dir to $dir ($tstamp).\n";

mkdir $archdir, 0755;
mkdir "$archdir/$dir", 0755;

my $tmpdir = $dir;
$tmpdir =~ s|.*/||gio;

my $DATA = $archdir;

opendir( my $linkdir, $DATA );
while ( my $file = readdir($linkdir) ) {
    if ( -l "$DATA/$file" ) {
        if ( readlink("$DATA/$file") eq $tmpdir ) {
            unlink("$DATA/$file");
        }
    }
}
closedir($linkdir);
unlink("$DATA/$tstamp");
symlink( $tmpdir, "$DATA/$tstamp" );

unlink("$DATA/latest");
symlink( "$tstamp", "$DATA/latest" );

system(
    "/usr/bin/rsync",   "-a",                "--force",  "--delete",
    "--exclude=\*.tmp", "--delete-excluded", "$srcdir/", "$archdir/$dir/"
);

print "Archiving completed.\n";
