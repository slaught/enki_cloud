# Implements access to DNS
# The expected format of the URL/request is name://<hostname>:<port>/<hostname_to_query>
# for example, name://localhost:53/example.com

package LWP::Protocol::name;

use vars qw(@ISA);
require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;

require HTTP::Request;
require HTTP::Response;
require HTTP::Status;
require HTTP::Date;

sub request
{
    my($self, $request, $proxy, $arg, $size) = @_;
  	my $proto = "name";

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

    # check path
    my $check_addr;
    if ($url->path =~ /^\/(.+)$/) {
      $check_addr = $1;  
    }
    my ($server, $port) = split(':', $url->authority);
    if (not($port =~ /^\d+$/ && defined $check_addr)) {
	    return new HTTP::Response &HTTP::Status::RC_BAD_REQUEST,
				'Invalid DNS Check URL format.';
    }

    # URL OK, look at file
	  my $rc =  check_dns($server, $port, $check_addr); 
    # test file exists and is readable
    if ($rc != 0 ) {
	    return new HTTP::Response &HTTP::Status::RC_NOT_FOUND, "Failed dns check";
    }
    # XXX should check Accept headers?
    # Ok, should be an OK response by now...
    my $response = new HTTP::Response &HTTP::Status::RC_OK;
    if ($method ne "HEAD") {
    	$response =  $self->collect_once($arg, $response, '');
    }
    return $response;
}


# check_dns($server, $port)
# returns 0 for success, 1 else
sub check_dns
{
  my ($server, $d_port, $request) = @_;

	my $res;
	my $query;
	my $rr;
	{
		# Net::DNS makes unguarded calls to eval
		# which throw a fatal exception if they fail
		# Needless to say, this is completely stupid.
		local $SIG{'__DIE__'} = "DEFAULT";
		require Net::DNS;
	}
	$res = new Net::DNS::Resolver;

	eval {
		local $SIG{'__DIE__'} = "DEFAULT";
		local $SIG{'ALRM'} = sub { die "timeout\n"; };
		alarm(5);
		$res->nameservers($server);
		$query = $res->search($request);
		alarm(0);
	};

	if ($@ eq "timeout\n" or ! $query) {
		return 1;
	}
  return 0;
}

1;
