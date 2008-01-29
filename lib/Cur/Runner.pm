package Cur::Runner;
use Moose;
use Cur;

with qw(MooseX::SimpleConfig);

has app => (
    isa     => 'Cur',
    is      => 'ro',
    builder => '_build_app',
    handles => [qw(run server)],
);

has handlers => (
    isa        => 'HashRef',
    is         => 'ro',
    auto_deref => 1,
    builder    => 'default_handlers',
);

sub _build_app {
    my $app = Cur->new_with_options();
    $app->server->register_handler( $_[0]->handlers );
    return $app;
}

sub default_handlers {
    return {};
}

no Moose;
1;
__END__
