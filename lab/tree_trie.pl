#!/usr/bin/env perl
use strict;
use Tree::Trie;
use Test::More no_plan => 1;

# Testing longest prefix lookup
my $tree = Tree::Trie->new( { deepsearch => 'prefix' } );

sub register {
    my $name = $_[0];
    $tree->add_data( $name => sub { $name } );
}

for (qw(/ /usr /usr/local /var)) {
    register($_);
}

is( $tree->lookup_data('/usr/foo.txt')->(), '/usr', 'foo.txt in /usr' );
is( $tree->lookup_data('/usr/lo')->(),      '/usr', 'lo in /usr' );
is( $tree->lookup_data('/usr/local/')->(),
    '/usr/local', '/usr/local/ in /usr/local/' );
is( $tree->lookup_data('/usr/local/bar.html')->(),
    '/usr/local', 'bar.html in /usr/local/' );
is( $tree->lookup_data('/foo')->(), '/', 'bar.html in /' );
