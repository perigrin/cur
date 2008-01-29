package Cur::Server;
use Cogwheel;
use Cache::Memory;
use Tree::Trie;
use Cur::Server::Plugin;

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

has content_cache => (
    isa        => 'Object',
    is         => 'ro',
    lazy_build => 1,
    handles    => {
        cache_set => 'set',
        cache_get => 'get'
    },
);

sub _build_handler_map {
    return Tree::Trie->new( { deepsearch => 'prefix' } );
}

sub _build_content_cache {
    return Cache::Memory->new(
        cache_root      => '/tmp/mycache',
        default_expires => '600 sec'
    );
}

sub run { POE::Kernel->run() }

no Cogwheel;
1;
__END__
