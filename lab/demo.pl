#!/usr/local/bin/perl 
use POE qw(XS::Queue::Array);

use lib qw(lib);
use Moose;

use POE::Component::Supervisor;
use POE::Component::Supervisor::Supervised::Child;

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
use POE::Component::Supervisor;

use POE;

with qw(MooseX::Getopt);

has _manager => (
    isa        => 'POE::Component::Supervisor',
    is         => 'ro',
    lazy_build => 1,
    handles    => {
        add_child => "start",
    },
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
    default => sub { '0.0.0.0' },
);

has ports => (
    isa        => 'ArrayRef[Int]',
    is         => 'ro',
    default    => sub { [ 31335 ... 31339 ] },
    auto_deref => 1,
);

sub _build__manager {
    my $self = shift;

    POE::Component::Supervisor->new(
        children => [
            map {
                my $port = $_;
                my $bind = $self->ip_address;

                POE::Component::Supervisor::Supervised::Child->new(
                    restart_policy => "permanent",
                    stdout_callback => sub {
                        $_[OBJECT]->logger->info( "child stdout: " . $_[ARG0] ),
                    },
                    stderr_callback => sub {
                        $_[OBJECT]->logger->info( "child stderr: " . $_[ARG0] ),
                    },
                    program => sub {
                        POE::Session->create(
                            inline_states => {
                                _start => sub {
                                    warn "starting cur: ",
                                    my $cur = Cur->new( address => $bind, port => $port );
                                    $_[HEAP]{cur_instance} = $cur;
                                    $cur->server->start;
                                },
                            },
                        );
                    },
                );
            } $self->ports
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

    POE::Session->create(
        inline_states => {
            _start => sub { $self->_manager },
        }
    );

    $poe_kernel->run;
}

before 'run' => sub {
    my %handlers = $_[0]->_handlers;
    while ( my ( $uri, $obj ) = each %handlers ) {
        printf( "handler for %s: %s\n", $uri, ( blessed $obj || $obj ) );
    }
};


my $obj = __PACKAGE__->new_with_options();

$obj->run();

END { 
    $obj->_manager->stop;
}

__END__
