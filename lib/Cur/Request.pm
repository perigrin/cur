package Cur::Request;
use Moose;

has raw => (
    isa     => 'HTTP::Request',
    is      => 'rw',
    handles => [qw(protocol uri header)],
);

has start_time => (
    isa     => 'Str',
    is      => 'ro',
    default => sub { time() },
);

has content => (
    isa       => 'Str',
    is        => 'rw',
    predicate => 'has_content',
);

has content_length => (
    isa     => 'Int',
    is      => 'rw',
    lazy    => 1,
    default => sub { length( $_[0]->content ) },
);

has keep_alive => (
    isa       => 'Bool',
    is        => 'rw',
    predicate => 'has_keep_alive',
);

has forwarded_from => (
    isa => 'Str',
    is  => 'rw',
);

has plugin => (
    isa     => 'Cur::Server::Plugin',
    is      => 'ro',
    weaken  => 1,
    handles => [qw(server)],
);

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
