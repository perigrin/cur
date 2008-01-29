# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'MooseX-Cache';
all_from 'lib/MooseX/Cache.pm';

# Specific dependencies
requires 'Moose'                => '0.33';
requires 'MooseX::Getopt'       => undef;
requires 'MooseX::SimpleConfig' => undef;
requires 'MooseX::Daemonize'    => undef;
requires 'Cogwheel'             => '0.01';
requires 'Tree::Trie'           => '1.5';
requires 'Cache'                => '2.04';

sub kwalitee() {
    return <<'END';
use Test::More;
eval "use Test::Kwalitee";
plan skip_all => "Test::Kwalitee not installed; skipping" if $@;
END
}

if ( $ENV{DEVELOPER_TESTS} ) {
    use_test_base;
    use_standard_tests;
    write_test( '000_kwalitee' => kwalitee );
}

auto_install;
WriteAll;
