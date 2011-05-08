# Implements access to lvs:-URLs as specified in RFC 2397

package LWP::Protocol::lvs;

use vars qw(@ISA);
require LWP::Protocol;
@ISA = qw(LWP::Protocol);

use strict;

#require LWP::MediaTypes;
require HTTP::Request;
require HTTP::Response;
require HTTP::Status;
require HTTP::Date;
use Perl6::Slurp;

sub request
{
    my($self, $request, $proxy, $arg, $size) = @_;
  	my $proto = "lvs";

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
    my $path  = substr($url->path,1);
    #print $path  . "\n";
	  my $rc =  &check_lvs_service($path); # split(':', $url->authority )); 
    #print $rc . "\n";
    # test file exists and is readable
    if ($rc != 0 ) {
	    return new HTTP::Response &HTTP::Status::RC_NOT_FOUND, "Failed $proto check";
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

sub check_lvs_service # fwmark  # check_simpletcp($server, $port)
{
  my $FILE = "/proc/net/ip_vs";
  my ($fwmark, $opts)  = @_;
  $fwmark = sprintf("%.8X", $fwmark);   # convert decimal value to 8-digit hex
  unless ( defined($fwmark) && $fwmark ne '' ) {
    return 3;
  }
  my $buf = slurp($FILE);
#LocalAddress:Port Scheduler Flags
#load2.test:   -> RemoteAddress:Port Forward Weight ActiveConn InActConn
#load2.test: FWM  7F000A01 wlc 
#load2.test:   -> 7F000A01:0000      Local   1      0          0         
#load2.test:   -> 0A086566:0000      Tunnel  0      0          0         
#load3.test: IP Virtual Server version 1.2.1 (size=32768)
#load3.test: Prot LocalAddress:Port Scheduler Flags
  if  ($buf =~  m/^FWM\s+$fwmark/m ) {
     #                   -> 7F000A01:0000      Local   1      0          0         
      if  ($buf =~  m/^\s+->\s+$fwmark(..000.+)\s+Local\s+1/m ) {
        return 2; # running downpage
      } else {
        return 0; # service with no down page
      }
  } else {
    # print $buf;
    # no service defined
    return 1;
  }
}

sub main {
  # $_ = shift;
  # shift;
  my ($fwm, undef) = @_; 
  my $rc = &check_lvs_service($fwm);
  print "Found $rc, $fwm \n";
}

1;
