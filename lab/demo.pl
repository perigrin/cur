#!/usr/local/bin/perl 
use POE qw(XS::Queue::Array);

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
use Proc::Supervisor;

with qw(MooseX::Getopt);

has _manager => (
    isa        => 'Proc::Supervisor',
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw(add_child)],
);

has _handlers => (
    isa        => 'HashRef',
    is         => 'ro',
    auto_deref => 1,
    lazy_build => 1,
    builder    => 'default_handlers',
);

has ip_address => (
    isa     => 'Str',
    is      => 'ro',
    default => sub { '78.47.126.42' },
);

has ports => (
    isa        => 'ArrayRef[Int]',
    is         => 'ro',
    default    => sub { [ 31335 ... 31339 ] },
    auto_deref => 1,
);

sub _build__manager {
    my $manager = Proc::Supervisor->new(
        children => [
            map {
                Proc::Supervisor::Proc->new( setup_callback => sub { $_->run } )
              }
              map { Cur->new( address => $_[0]->ip_address, port => $_ ) }
              $_[0]->ports
        ],
    );
}

sub default_handlers {
    return {
        '/'          => CurApp::Simple->new(),
        '/dahut'     => 'CurApp::Dahut',
        '/foo'       => 'CurApp::Dahut',
        '/foo/quine' => CurApp::Quine->new( file => 'bin/simple_handler.pl' ),
    };
}

sub run {
    my ($self) = @_;
    $self->_manager->start;
}

before 'run' => sub {
    my %handlers = $_[0]->_handlers;
    while ( my ( $uri, $obj ) = each %handlers ) {
        printf( "handler for %s: %s\n", $uri, ( blessed $obj || $obj ) );
    }
};


my $obj = __PACKAGE__->new_with_options()->run();

END { 
    $obj->manager->stop;
}

__END__
