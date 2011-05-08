# Implements access to cassandra 

package LWP::Protocol::cassandra;

use vars qw(@ISA);
require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;
use warnings;
use Net::Cassandra::Cassandra;

use Thrift;
use Thrift::Socket;
use Thrift::FramedTransport;
use Thrift::BinaryProtocol;

require HTTP::Request;
require HTTP::Response;
require HTTP::Status;
require HTTP::Date;
require Net::SMTP;

my $EXPECTED_CLUS_NAME = 'Sessions';

sub request
{
  my($self, $request, $proxy, $arg, $size) = @_;
  my $proto = "cassandra";

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
  my $rc =  check_cassandra(split(':',$url->authority )); 
  # test file exists and is readable
  if ($rc != 0 ) {
    return new HTTP::Response &HTTP::Status::RC_NOT_FOUND, "Failed cassandra check";
  }
  # XXX should check Accept headers?
  # Ok, should be an OK response by now...
  my $response = new HTTP::Response &HTTP::Status::RC_OK;
  if ($method ne "HEAD") {
    $response =  $self->collect_once($arg, $response, '');
  }
  return $response;
}

# check_cassandra($server, $port)
# returns 0 for success, 1 else
sub check_cassandra
{
  my ($server, $d_port) = @_;

  my $socket = new Thrift::Socket($server, $d_port);
  my $transport = new Thrift::FramedTransport($socket,1024,1024);
  my $protocol = new Thrift::BinaryProtocol($transport);
  my $client = new Net::Cassandra::CassandraClient($protocol);

  eval {
     $transport->open();
     my $cluster_name = $client->describe_cluster_name();
     die 'Unexpected cluster name!' if not($cluster_name eq $EXPECTED_CLUS_NAME); 
     $transport->close();
  };

  if ($@) {
    return 1;  
  }
  else {
    return 0;
  }
}

1;
