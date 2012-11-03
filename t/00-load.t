#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Acme::MobileTradeFun' ) || print "Bail out!\n";
}

diag( "Testing Acme::MobileTradeFun $Acme::MobileTradeFun::VERSION, Perl $], $^X" );