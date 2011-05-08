# Implements access to piivr:-URLs as specified in RFC 2397

package LWP::Protocol::piivr;

use vars qw(@ISA);
require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;

#require LWP::MediaTypes;
require HTTP::Request;
require HTTP::Response;
require HTTP::Status;
require HTTP::Date;

sub request
{
    my($self, $request, $proxy, $arg, $size) = @_;
  	my $proto = "piivr";

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
	return new HTTP::Response &HTTP::Status::RC_INTERNAL_SERVER_ERROR, ref($self) . "::request called for '$scheme'";
    }

    # URL OK, look at file
    my $path  = $url->path;
	  my $rc =  &check_simpletcp(split(':',$url->authority )); 
    # test file exists and is readable
    if ($rc != 0 ) {
	    return new HTTP::Response &HTTP::Status::RC_NOT_FOUND, "Failed piivr check";
    }
    # XXX should check Accept headers?
    # Ok, should be an OK response by now...
    my $response = new HTTP::Response &HTTP::Status::RC_OK;

    # fill in response headers
    #$response->header('Last-Modified', HTTP::Date::time2str($mtime));

    # read the file
	 ## my $contents = $revision->get_contents();
    if ($method ne "HEAD") {
    	$response =  $self->collect_once($arg, $response, '');
    }
    return $response;
}


# check_simpletcp($server, $port)
sub check_simpletcp
{
       my ($server, $d_port) = @_;
my $request = "agi_network: true\nagi_request: agi://localhost:4570/\nagi_context: nephilim\n\n";
my	$receive="ANSWER";
#       my $d_port = 45707;
#      my $server = "10.8.35.101";
#        $server = '10.11.12.54';
#        $server = '172.23.1.10';
#        $server = '127.0.0.1';
       #print "Checking simpletcp server=$server port=$d_port\n";
       eval {
	       use Socket;
	       local $SIG{'__DIE__'} = "DEFAULT";
	       local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
	       alarm 2 ;
	       my $sock = &ld_open_socket($server, $d_port, "tcp");
	       unless ($sock) {
		       alarm 0;
		       die("Socket Connect Failed");
	       }
	       my $s_sockaddr = getsockname($sock);
	       my ($s_port, $s_addr) = sockaddr_in($s_sockaddr);
	       my $s_addr_str = inet_ntoa($s_addr);
	     #  print "Connected from $s_addr_str:$s_port to " .  $server .  ":$d_port\n";
	       select $sock;
	       $|=1;
	       select STDOUT;
	       #my $request = $request;
	       $request =~ s/\\n/\n/g ;

	     #  print "Checking simpletcp server=$server port=$d_port request:\n$request";
	       print $sock $request;

	       my $ok;
	       my $reply = '';
	       my $cnt = 0;
	       my $b = 0;
	       while (1) {
		       my $buf = '';
		       my $b = sysread($sock, $buf, 6 );
		    # print "Checking simpletcp server=$server port=$d_port receive=" . $receive ." got: $reply$b\n";
		       if ( $b > 0 ) { $reply = $reply . $buf }
		       if ( $reply =~ /$receive/ ) {
			       $ok = 1;
			       last;
		       }
                      if ( $cnt > 10 ) { last; } else { $cnt++; }
	       }
	       alarm 0; # Cancel the alarm
	       close($sock);

	       if (!defined $ok) {
		       die "No OK\n";
	       }
       };

       if ($@) {
	     #  print "down\n" ;
	     #  print "Deactivated service $server:$d_port: $@";
	       return 1;
       } else {
	     #  print "up\n";
	     #  print "Activated service $server:$d_port";
	       return 0;
       }
}
# &check_simpletcp();

# ld_open_socket
# Open a socket connection
# pre: remote: IP address as a dotted quad of remote host to connect to
#      port: port to connect to
#      protocol: Prococol to use. Should be either "tcp" or "udp"
# post: A Socket connection is opened to the remote host
# return: Open socket
#         undef on error

sub ld_open_socket
{
	my ($remote, $port, $protocol) = @_;
	my ($iaddr, $paddr, $pro, $result);
	local *SOCK;

	$iaddr = inet_aton($remote) || die "no host: $remote";
	$paddr = sockaddr_in($port, $iaddr);
	$pro = getprotobyname($protocol);
	if ($protocol eq "udp") {
		socket(SOCK, PF_INET, SOCK_DGRAM, $pro) || die "socket: $!";
	}
	else {
		socket(SOCK, PF_INET, SOCK_STREAM, $pro) || die "socket: $!";
	}
	$result = connect(SOCK, $paddr);
	unless ($result) {
		return undef;
	}
	return *SOCK;
}

1;
