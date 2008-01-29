package Cur::HTTPD;
use Moose;

with qw(MooseX::Daemonize);

has server => (
    isa      => 'Cur::Server',
    is       => 'ro',
    lazy     => 1,
    required => 1,
    default  => sub { Cur::Server->new() },
    handles  => { Port => 'ListenPort' },
);

after start => sub { POE::Kernel->run() if $_[0]->is_daemon; };

no Moose;
1;
__END__
