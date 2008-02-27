package Cur::Server;
use Cogwheel;
use Cache::Memory;
use Tree::Trie;

BEGIN {
    extends qw(Cogwheel::Server);
}

has aio => (
    isa     => 'Bool',
    is      => 'ro',
    default => sub { 0 },
);

has handler_map => (
    isa        => 'Tree::Trie',
    is         => 'ro',
    predicate  => 'has_handlers',
    lazy_build => 1,
    handles    => {
        register_handler => 'add_data',
        find_handler     => 'lookup',
        get_handler      => 'lookup_data'
    },
);

sub _build_handler_map {
    return Tree::Trie->new(
        {
            end_marker        => '\o/',
            freeze_end_marker => 1,
            deepsearch        => 'prefix'
        }
    );
}

sub run { POE::Kernel->run() }

no Cogwheel;
1;
__END__
