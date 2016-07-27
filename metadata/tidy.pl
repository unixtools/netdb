#!/usr/bin/perl

use strict;

use JSON;
my $json = new JSON;
$json->canonical(1);

foreach my $file ( glob("*.json") ) {
    open( my $in, "<$file" );
    my $json_text = join( "", <$in> );
    close($in);

    my %data;

    eval { %data = %{ from_json( $json_text, { utf8 => 1 } ) }; };
    if ($@) {
        print "$file: $@\n";
        next;
    }

    open( my $out, ">$file" );
    print $out $json->pretty->encode( \%data ), "\n";
    close($out);
}
