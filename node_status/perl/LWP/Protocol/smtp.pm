# Implements access to smtp

package LWP::Protocol::smtp;

use vars qw(@ISA);
require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;
# use IO::Socket;

#require LWP::MediaTypes;
require HTTP::Request;
require HTTP::Response;
require HTTP::Status;
require HTTP::Date;
require Net::SMTP;

sub request
{
    my($self, $request, $proxy, $arg, $size) = @_;
  	my $proto = "smtp";

    $size = 4096 unless defined $size and $size > 0;

    # check proxy
    if (defined $proxy)
    {
      	return new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
				  "You can not proxy through $proto";
    }

    # check method
    my $method = $request->method;
    unless ($method eq 'GET' || $method eq 'HEAD') {
	return new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
				  'Library does not allow method ' .
				  "$method for '$proto:' URLs";
    }

    # check url
    my $url = $request->url;
    my $scheme = $url->scheme;
    if ($scheme ne $proto ) {
	  return new HTTP::Response &HTTP::Status::RC_INTERNAL_SERVER_ERROR,
      ref($self) . "::request called for '$scheme'";
    }

    # URL OK, look at file
    my $path  = $url->path;
	  my $rc =  check_smtp(split(':',$url->authority )); 
    # test file exists and is readable
    if ($rc != 0 ) {
	    return new HTTP::Response &HTTP::Status::RC_NOT_FOUND, "Failed smtp check";
    }
    # XXX should check Accept headers?
    # Ok, should be an OK response by now...
    my $response = new HTTP::Response &HTTP::Status::RC_OK;
    if ($method ne "HEAD") {
    	$response =  $self->collect_once($arg, $response, '');
    }
    return $response;
}


# check_smtp($server, $port)
# returns 0 for success, 1 else
sub check_smtp
{
  my ($server, $d_port) = @_;
  # my $response;

	my $smtp = new Net::SMTP($server, Port => $d_port,
			Timeout => 5);
	if ($smtp) {
		$smtp->quit;
    return 0;
	} else {
    return 1;
	}
}

1;
