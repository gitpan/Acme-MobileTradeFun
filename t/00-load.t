#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Path qw/remove_tree/;

BEGIN {
    unshift @INC, "$Bin/../lib";
    use_ok( 'Acme::MobileTradeFun' ) || print "Bail out!\n";
}

diag( "Testing Acme::MobileTradeFun $Acme::MobileTradeFun::VERSION, Perl $], $^X" );

my $obj = eval{ Acme::MobileTradeFun->new(); };
like( $@, qr/game not specified/, 'new() test with bad input' );

my $args = {
    game        => 'idolmaster',
    output_dir  => "$Bin",
    debug       => 0,
};

$obj = Acme::MobileTradeFun->new( $args );
isa_ok( $obj, 'Acme::MobileTradeFun', 'new() test with good input' );

# cleanup at the end of test
remove_tree( "$Bin/idolmaster" );

done_testing();