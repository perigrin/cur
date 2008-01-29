package Cur::Server::Plugin;
use Cogwheel;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status qw( status_message is_info RC_BAD_REQUEST );
use POE qw(Filter::HTTPD);
use Time::HiRes qw( time );
use HTTP::Date;
use Cur::Request;

extends qw(Cogwheel::Plugin);

sub OK()    { 1 }
sub DEFER() { 0 }
sub BAD()   { undef }

has request => (
    isa        => 'Cur::Request',
    is         => 'rw',
    predicate  => 'has_request',
    clearer    => 'clear_request',
    lazy_build => 1,
    handles    => [qw(content has_content content_length)],
);

has response => (
    isa        => 'HTTP::Response',
    is         => 'rw',
    predicate  => 'has_response',
    lazy_build => 1,
);

has server => (
    isa     => 'Str',
    is      => 'ro',
    weaken  => 1,
    handles => [qw(get_handler find_handler register_handler)]
);

sub _build_request {
    Cur::Request->new( plugin => $_[0] );
}

sub _build_response {
    HTTP::Response->new(500);
}

# Stolen straight from Sprocket
sub local_connected {
    my ( $self, $server, $con, $socket ) = @_;
    $self->take_connection($con);
    $con->filter->push( POE::Filter::HTTPD->new() );
    $con->set_time_out(5);
}

sub start_http_request {
    my ( $self, $server, $con, $req ) = @_;

    $self->clear_request() if $self->has_request;

    my $type = blessed($req);
    unless ($type) {
        $self->close_connection(1);
        $con->call( finish => 'invalid request' );
        return BAD;
    }

    $type eq 'HTTP::Response'
      ? $self->response($req)
      : $self->request->raw($req);

    unless ( $self->has_request ) {
        my $req = $self->response;
        $con->call('finish');
        return DEFER;
    }
    return OK;
}

sub local_receive {
    my ( $self, $server, $con, $req ) = @_;
    my $ok_retval = $self->start_http_request( $server, $con, $req );
    return $ok_retval unless $ok_retval;

    $req = $self->request;
    $con->wheel->pause_input();    # no more requests
    $con->set_time_out(undef);

    unless ( $server->has_handlers ) {
        $con->call( simple_response => 500, 'No Handlers Installed!' );
        return OK;
    }

    my $uri = $req->uri;
    if ( my $content = $server->cache_get( $req->uri ) ) {
        $self->response( HTTP::Response->new(200) );
        $self->content($content);
        $con->call('finish');
        return OK;
    }

    if ( my $handler = $server->get_handler($uri) ) {
        if ( my $data = $handler->handler($req) ) {
            $self->content($data);
            $server->cache_set( $uri => $data );
            $self->response( HTTP::Response->new(200) );
            $con->call('finish');
            return OK;
        }
    }

    unless ( $self->has_response ) {
        $con->call(
            'simple_response' => 404,
            'Handler not found for URI.'
        );
    }
    return OK;
}

our %simple_responses = (
    403 => 'Forbidden',
    404 => 'The requested URL was not found on this server.',
    500 => 'A server error occurred',
);

sub simple_response {
    my ( $self, $server, $con, $code, $extra ) = @_;
    $code ||= 500;

    # XXX do something else with status?
    my $status = status_message($code) || 'Unknown Error';
    my $r = $self->response;
    $r->code($code);

    if ( $code == 301 || $code == 302 ) {
        $r->header( Location => $extra || '/' );
        $con->call('finish');
        return;
    }
    elsif ( is_info($code) ) {
        $con->call('finish');
        return;
    }

    my $body = $simple_responses{$code} || $status;

    if ( defined $extra ) {
        $body .= '<p>' . $extra;
    }

    $r->content_type('text/html');
    $self->content(
        qq{
        <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
        <html>
            <head>
                <title>$code $status</title>
            </head>
            <body>
                <h1>$status</h1>
                $body
            </body>
        </html>
    }
    );
    $con->call('finish');
}

sub finish {
    my ( $self, $server, $con ) = @_;

    my $r = $self->response;

    # TODO real version here
    $r->header( Server => 'Cogwheel-HTTPD/1.0' );
    $r->header(
        'X-Powered-By' => join '; ',
        (
            'Coghweel (???)',
            'Sprocket (http://sprocket.xantus.org/)',
            'Cometd (http://cometd.com/)',
            'Moose (???)',
            'POE (http://poe.perl.org/)',
            'Perl (http://perl.org/)',
        )
    );

    my $time = time();
    $r->header( 'X-Time-To-Serve' => ( $time - $self->request->start_time ) );
    $r->header( Date              => time2str($time) );

    # TODO
    # in request:
    # TODO Accept-Encoding  gzip,deflate
    # TODO Keep-Alive: 300

    my $req   = $self->request;
    my $proto = $req->protocol;
    $r->protocol($proto);

    if ( $proto && $proto eq 'HTTP/1.1' ) {

        # in 1.1, keep-alive is assumed
        $req->keep_alive(1) unless $req->has_keep_alive;
    }
    elsif ( $proto && $proto eq 'HTTP/1.0' ) {
        unless ( $req->has_keep_alive ) {
            my $connection = $req->header('connection');
            if ( $connection && $connection =~ m/^keep-alive$/i ) {
                $r->header( 'Connection' => 'keep-alive' );
                $req->keep_alive(1);
            }
            else {
                $req->keep_alive(0);
            }
        }
    }
    else {
        $req->keep_alive(0);
    }

    # XXX check for content length if keep-alive?
    if ( $self->has_content ) {
        my $out = $self->content;
        $r->content( $self->content );
        $r->header( 'Content-Length' => $self->content_length );
    }

    if ( $con->can('clid') ) {
        if ( my $clid = $con->clid ) {
            $r->header( 'X-Client-ID' => $clid );
        }
    }

    $r->header( 'X-Sprocket-CID' => $con->ID );

    unless ( $req->keep_alive ) {
        $r->header( 'Connection' => 'close' );
        $con->wheel->pause_input();    # no more requests
        $con->send($r);
        $con->close();
    }
    else {

        # TODO set/reset timeout
        $con->send($r);
        $self->{__requests}++;
        $con->wheel->resume_input();
    }

    if ( $r->code == 400 ) {
        $self->log( v => 1, msg => '400 bad request' );
        return OK;
    }

    # TODO log full request`
    $self->log(
        v   => 1,
        msg => join(
            ' ',
            ( $req ? $req->protocol : '?' ),
            $r->code,
            (
                $r->header('X-Time-To-Serve')
                ? sprintf( '%.5g', $r->header('X-Time-To-Serve') )
                : '?'
            ),
            ( defined $req->content_length ? $req->content_length : '-' ),
            ( $req                         ? $req->uri            : '?' ),
            ( $r->code && $r->code == 302 ? $r->header('Location') : '' )
        )
    );

    return OK;
}
no Cogwheel;
__PACKAGE__->meta->make_immutable;
1;
__END__
