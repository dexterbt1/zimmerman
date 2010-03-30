#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Hello::World' ) || print "Bail out!
";
}

diag( "Testing Hello::World $Hello::World::VERSION, Perl $], $^X" );
