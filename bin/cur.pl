#!/usr/bin/env perl
use Cwd;
use lib qw(lib);

{

    package Cur::Daemon use Moose;
    extends Cur::Runner;
    with qw(MooseX::Daemonize);

    after 'start' => sub { $_[0]->app->run if $_[0]->is_daemon };
}
my $app = Cur::Runner->new_with_options( pidbase => getcwd );

my ($cmd) = @{ $app->extra_argv };
warn $cmd;
die "must provide a command (start|stop|restart)" unless defined $cmd;

print STDERR "trying to $cmd server\n";

if ( $cmd eq 'start' ) {
    print STDERR <<"EOT";
    pidfile: @{ [ $app->pidfile ] }
    port:    @{ [ $app->Port ] }
EOT
}

$app->$cmd;
warn( $app->status_message );
exit( $app->exit_code );
