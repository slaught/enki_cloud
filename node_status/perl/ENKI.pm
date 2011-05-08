
use strict;
package ENKI;

use ENKI::Status;

use Nginx::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common;
use URI;

use Perl6::Slurp qw(slurp);

    sub main # mandatory
    {
        my $self = shift;

        $self->header_set('Content-Type' => 'text/plain');

        my @uris = split(/\//, $self->uri);
        if ($uris[1] eq 'services') {
          my ($str, $h) = &ENKI::Status::services($self);
          if ( $h < 1 ) { 
            $self->status(404);
          } else {
            $self->print($str); 
            $self->status(200);
          }
        }
        elsif ($uris[1] eq 'status' || $uris[1] eq 'state') {
          my ($s, $h) = &ENKI::Status::status($self) ;
          $self->print($s) ; 
         # $self->log("chad is in the house\n");
          if ( $h == 0 ) { 
            $self->status(503);
          } elsif ( $h == -1 ) {
            $self->status(404);
          } else {
            $self->status(200);
          }
        }
        else {
          $self->status(400);  
        }
    }

    # (optional) triggered after main runs
    sub cleanup
    {
        my $self = shift;
        # do stuff here---like clean database connections?
    }

    # (optional) triggered on a server error, otherwise it will return a standard nginx 500 error
    sub error
    {
        my $self = shift;
        my $error = shift;
        $self->status(500);
        $self->print("ERROR: Problem with nginx ENKI::Status module.! ($error)");
    }

1;
__END__
