use lib qw(lib);
use Moose;

{

    package CurApp::Dahut;
    sub handler { return 'DAHUT'; }
}

{

    package CurApp::Simple;
    use Moose;
    use File::Slurp qw(slurp);

    has file => (
        isa     => 'Str',
        is      => 'ro',
        default => sub { 'index.html' },
    );

    sub handler {
        my ( $self, $req ) = @_;
        return slurp( $self->file );
    }

    no Moose;
}

{

    package CurApp::Quine;
    use Moose;
    extends qw(CurApp::Simple);

    around 'handler' => sub {
        my ( $next, $self ) = ( shift, shift );
        $_ = $self->$next(@_);

        # litterally copied from jrockway's IRC foo
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/'/&apos;/g;
        s/"/&quot;/g;
        return "<pre>$_</pre>";
    };
    no Moose;
}

package CurApp::Runner;
use Moose;
use Cur;

with qw(MooseX::Getopt);

has port => (
    isa => 'Int',
    is  => 'ro',
);

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
    lazy_build => 1,
    builder    => 'default_handlers',
);

sub _build_app {
    my $app = Cur->new( address => '78.47.126.42', port => $_[0]->port );
    $app->server->register_handler( $_[0]->handlers );
    return $app;
}

sub default_handlers {
    return {
        '/'          => CurApp::Simple->new(),
        '/dahut'     => 'CurApp::Dahut',
        '/foo'       => 'CurApp::Dahut',
        '/foo/quine' => CurApp::Quine->new( file => 'bin/simple_handler.pl' ),
    };
}

before 'run' => sub {
    my %handlers = $_[0]->server->get_handler('');
    while ( my ( $uri, $obj ) = each %handlers ) {
        printf( "handler for %s: %s\n", $uri, ( blessed $obj || $obj ) );
    }
};

no Moose;

__PACKAGE__->new()->run();

__END__
