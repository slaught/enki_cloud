# Implements access to postgresql

package LWP::Protocol::postgresql;

use vars qw(@ISA);
require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;
use IO::Socket;
use Digest::MD5;

require HTTP::Request;
require HTTP::Response;
require HTTP::Status;
require HTTP::Date;

my $USERNAME = 'postgres';
my $PASSWORD = 'somepassword';
my $PROTO_VERSION = 196608; 
my $DATABASE = 'postgres';
my $SOCK_PREFIX = '.s.PGSQL.';
my $ERROR_FORMAT = 'A1NZ1Z5xZ1Z5';

sub request
{
    my($self, $request, $proxy, $arg, $size) = @_;
  	my $proto = "postgresql";

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

    # URL OK, test database
	  my $rc =  &check_postgresql($url);
    if ($rc != 0 ) {
	    return new HTTP::Response &HTTP::Status::RC_NOT_FOUND, "Failed postgresql check";
    }
    # Ok, should be an OK response by now...
    my $response = new HTTP::Response &HTTP::Status::RC_OK;
    if ($method ne "HEAD") {
    	$response =  $self->collect_once($arg, $response, '');
    }
    return $response;
}

sub parse_url
{
  my $authority = shift;
  my @parts = split(':', $authority);
  my $port = $parts[-1];
  @parts = split('@', $parts[-2]);
  my $server = $parts[-1];
  my $user = get_username($authority);
  return ($server, $port, $user);
}

sub get_username
{
  my $authority = shift;
  if ($authority =~ /^(.+)@.+$/) {
    my @temp = split(':', $1);
    return $temp[0];
  } else {
    return undef; 
  }
}

sub send_command
{
  my ($sock, $send_data, $recv_format, $head_byte) = @_;
  my $packet;
  my $response;
  my $salt;
  
  $packet = finish_packet($send_data, $head_byte);
  $sock->send($packet);
  $sock->recv($response, 1000);

  my @parts = unpack($recv_format, $response);
  if ($send_data =~ /user/ and $parts[2] eq '5') {
    $salt = $parts[-1];
    return (join('|', @parts), $salt);
  } else {
    return join('|', @parts);
  }
}

sub finish_packet
{
  my ($packet, $head_byte) = @_;

  if ($head_byte) {
    return $head_byte . pack('N', length($packet) + 4) . $packet;
  } else {
    return pack('N', length($packet) + 4). $packet;
  }
}

# taken from DBD::PgPP
sub encode_md5 {
    my ($user, $password, $salt) = @_;

    my $md5 = Digest::MD5->new;
    $md5->add($password);
    $md5->add($user);

    my $tmp_digest = $md5->hexdigest;
    $md5->add($tmp_digest);
    $md5->add($salt);

    return 'md5' . $md5->hexdigest;
}

# http://www.postgresql.org/docs/8.3/static/protocol-message-formats.html
sub check_postgresql
{
  my $url = shift;
  # have to parse ourselves because userinfo(), host() etc are not supported in URI::foreign
  my ($server, $d_port, $username) = parse_url($url->authority);
  my ($sock, $packet, $response, $salt);
  my @parts;
  $username = $username || $USERNAME;

  eval {
    # if using UNIX socket, path should be something like /var/run/postgresql(path to actual socket on filesystem)
    if (length($url->path)) {
      my $path = (substr($url->path, -1, 1) eq '/') ? $url->path : $url->path.'/';
      $sock = new IO::Socket::UNIX (
        Peer => $path . $SOCK_PREFIX . $d_port
      );
    } else {
      $sock = new IO::Socket::INET (
        PeerAddr => $server,
        PeerPort => $d_port,
        Proto => 'tcp',
        Timeout => 5
      );
    }
    die("Socket Connect Failed") unless $sock;

    # startup
    $packet = pack('N', $PROTO_VERSION) . "user\0$username\0\0";
    ($response, $salt) = send_command($sock, $packet, 'A1NNa4');
    die 'No OK!' if not($response =~ /^R/);

    if ($salt) {
      # send password
      $packet = encode_md5($username, $PASSWORD, $salt);
      $response = send_command($sock, $packet, 'A1NN', 'p');
      die 'No OK!' if not($response =~ /^R/);
    }

    # send no-op 
    $packet = "SELECT 1;\0";
    $response = send_command($sock, $packet, 'A1NnZ9NnNnNn', 'Q');
    @parts = split('\|', $response);
    die 'No OK!' if (length($response) <= 1);
    die 'No OK!' if not($parts[0] eq 'T' and $parts[2] eq '1' and $parts[3] eq '?column?');

    $sock->close();
  };
  if ($@) {
    return 1;
  } else {
    return 0;
  }

}

1;
