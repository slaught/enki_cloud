

package ENKI::Status;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(status );
our @EXPORT_OK = qw(down_file is_admin_down checkurl);
our $VERSION = 1.0.0;


use strict;
use Perl6::Slurp;
use LWP::UserAgent;
#use HTTP::Cookies;
#use HTTP::Request::Common;
use URI;
use YAML qw(LoadFile);

my $DEBUG = 0;
my $LOCAL_SERVICES = "/etc/enki/configs/node/service.checks";
# configured for paths to serach for downpages
my @DOWNFILE_PATHS = qw(/ /enki/var/run/ );
my @SERVICE_DOWNFILE_PATHS = qw( /enki/var/tmp/services/ );

use constant YAML => 1;
use constant OLD => 2;
use constant INVALID => -1;
use constant CANT_READ => 0;

##############

# ignores comment lines that start with '#'
sub read_in_list {
  my @lines = ();
  my $u;

  # takes care of case where nginx is being run as root and file is not readable
  eval {
    $u = slurp($LOCAL_SERVICES);
  };
  return undef if ($@);

  foreach my $i (split /\n/, $u ) {
      $i =~ s/^\s*#.*$//;
      $i =~ s/^\s*$//;
      push(@lines, $i) if length($i);
  }
  return @lines;
}

sub checkurl {
  my $url = shift;
  my $ua = LWP::UserAgent->new();
  $ua->agent("ENKI::Status Check/1.0");
  $ua->timeout(2);
  my $res = $ua->get($url);
  #printHash($res);
  return $res->is_success; #$res->code ;
}


##############
sub down_file {
  my $d = shift;
  my $cluster_name = shift;
  if ($d && -e $d) {
    my $a;
    if ($cluster_name) {
      $a = "Comment: $cluster_name service is marked as down by local file: '$d'\n";
    } else {
      $a = "Comment: Server is marked as down by local file: '$d'\n" ;
    }
    if ( -r $d ) {
      $a = $a .  slurp($d) ;
    }
    return  $a;
  } else {
    return '';
  }
}
sub select_for_down_files
{
  my @paths = @_;

  foreach my $dir (@paths) {
    if ( opendir(DIR, $dir) ) {
      my @files = map { $dir . $_} grep { /down$/i } readdir(DIR);
      return @files if(scalar @files);
    }
    closedir(DIR);
  }
}
sub is_admin_down
{
  my @files = select_for_down_files(@DOWNFILE_PATHS);
  if (scalar @files) {
    return &down_file(shift @files);
  } 
  return undef;
}

sub is_service_down
{
  my $format = shift;
  my @services = @{shift()};
  my $q_ref = shift;
  my %query = %{$q_ref} if $q_ref;
  my $content = '';
  my @files = select_for_down_files(@SERVICE_DOWNFILE_PATHS);
  
  return '' if !(scalar @files);

  if ($format == YAML) {
    my @cluster_names;
    if (%query) {
      my @matches = all_service_matches(\%query, \@services);
      @cluster_names = map { $_->{'Cluster Name'} } all_service_matches(\%query, \@services);
    } else {
      @cluster_names = map { $_->{'Cluster Name'} } @services;
    }
    foreach my $file (@files) {
      next if not($file =~ m/^.+\/(.+)_down$/i);
      foreach my $cluster_name (@cluster_names) {
        $content = $content . down_file($file, $cluster_name) if lc($1) eq lc($cluster_name);
      }
    }
  } elsif ($format == OLD) {
    if (!%query) {
      foreach my $file (@files) {
        $content = $content . down_file($file);
      }
    }
  }

  return length($content) ? $content : undef;
}
sub all_service_matches (\%\@)
{
  my %query = %{shift()};
  my @services = @{shift()};
  my @matches = ();
  foreach my $service (@services) {
    push(@matches, $service) if is_service_match(\%query, $service);
  }
  return @matches;
}
##############

sub check_services_status_and_down {
  my $is_status = shift;
  my $query_ref = shift;
  my %query = %{$query_ref} if $query_ref;
  my ($format, @services) = service_checks_format();
  my ($found, $s);

  if (%query) {
    ($found, $s) = check_services($format, $is_status, \@services, \%query);
    if ($is_status) {
      $s = $s . is_service_down($format, \@services, \%query) if ($format != CANT_READ && $format != INVALID);
    }
  } else {
    ($found, $s) = check_services($format, $is_status, \@services);
    $s = $s . is_service_down($format, \@services) if ($format != CANT_READ && $format != INVALID);
  }
  return ($found, $s);
}

##############
sub parse_search {
  my $search = shift;
  my %query;

  foreach my $token (split /:|\//, $search) {
    if ($token =~ m/^(\d{1,3}\.){1,3}(\d{1,3})?$/) {
      $query{'ha_ip'} = $token;
    } elsif ($token =~ m/^\d+$/) {
      $query{'ha_port'} = $token;
    } elsif ($token =~ m/^(tcp|udp|icmp)$/i) {
      $query{'protocol'} = $token;
    } elsif ($token =~ m/^fwm=(\d+)$/i) {
      $query{'fwmark'} = $1;
    } else {
      $query{'cluster_name'} = $token;
    }
  }

  return %query;
}

# error - could not open file
# yaml file
# old format file
# unrecognized format
sub service_checks_format {
  my @services;
  my $old = 1;

  if (not (defined read_in_list())) {
    return (CANT_READ, undef);
  }
  my @lines = read_in_list();
  foreach (@lines) {
    $old = 0 if split(' ', $_) != 1;
  }
  return (OLD, @lines) if $old;   # if each line doesn't have any spaces, assume its old format
  eval {
    @services = @{LoadFile($LOCAL_SERVICES)};
  };
  if ($@) {
    return (INVALID, undef);
  } else {
    return (YAML, @services);
  }
}

sub check_services {
  my $format = shift;
  my $is_status = shift;
  my @services = @{shift()};
  my $q_ref = shift;
  my %query = %{$q_ref} if $q_ref;
  my $s = '';
  my $found = %query ? 0 : 1;

  if ($format == YAML) {
    foreach (@services) {
      if (%query) {
        if (is_service_match(\%query, \%{$_})) {
          $found = 1;
        } else {
          next;  
        }
      }
      if ( ((!$is_status && $_->{'Service Type'} eq 'state') ||
            (%query && $is_status) ||
            (!%query && $_->{'Service Type'} eq 'status')) &&
            not(checkurl($_->{'Check URL'})) ) { 
        $s = $s . "Failed check: ".$_->{'Check URL'}."\n" ;
      }
    }  
  } elsif ($format == OLD) {
    if (!%query) {
      foreach (@services) {
        unless ( checkurl($_) ) { 
           $s = $s . "Failed check: $_\n" ;
        }
      }  
    }
  } elsif ($format == INVALID) {
    if (%query) {
      $s = $s . "$LOCAL_SERVICES has an unrecognized file format!\n";
      $found = 0;
    }
  } elsif ($format == CANT_READ) {
    if (%query) {
      $s = $s . "Could not find or read $LOCAL_SERVICES!\n";
      $found = 0;
    }
  }

  return ($found, $s);
}

sub is_service_match (\%\%) {
  my %query = %{shift()};
  my %service = %{shift()};

  return (
    (exists $query{'ha_ip'} ? index($service{'IP Address'}, $query{'ha_ip'}) == 0 : 1) &&
    (exists $query{'ha_port'} ? $service{'HA Port'} == $query{'ha_port'} : 1) &&
    (exists $query{'protocol'} ? lc $service{'HA Proto'} eq lc $query{'protocol'} : 1) &&
    (exists $query{'fwmark'} ? $query{'fwmark'} eq $service{'Forward Mark'} : 1) &&
    (exists $query{'cluster_name'} ? index($service{'Cluster Name'}, $query{'cluster_name'}) != -1 : 1)
  );
}

sub contains_like ($@) {
  my ($match_str, @strs) = @_;
  foreach my $str (@strs) {
    return 1 if index($str, $match_str) != -1;
  }
  return 0;
}

#/********************************************************************************/
my $LOADAVG_FILE = "/proc/loadavg";
my $MEMINFO_FILE= "/proc/meminfo";

#/********************************************************************************/

sub loadavg() {
  my $buf = slurp($LOADAVG_FILE); 
  my ($avg_1, $avg_5, $avg_15, undef) = split(/\s/, $buf);
  return ($avg_1, $avg_5, $avg_15); 
}

sub services {
  my $str = '';
  my $h = 1;  # 1 for fine, -1 for not_found
  if(not defined read_in_list()) {
    $h = -1;  
  } else {
    foreach my $line (read_in_list()) {
      $str = $str . $line."\n";
    }
  }
  return ($str, $h);
}

sub status 
{
  my $modhandler = shift;
  my $buf = '';
  my $h;
  my $u;
  my @uris = split(/\//, $modhandler->uri, 4);
  my $d = &is_admin_down;
  my $found = 1;
  my %query;
  %query = parse_search($uris[3]) if $uris[3];

  # possible valid paths:
  # /status
  # /status/service/...
  # /status/health
  # /state/service/...
  if ($uris[1] eq 'status') {
    if ($uris[2] eq 'service' && $uris[3]) {
      ($found, $u) = check_services_status_and_down(1, \%query);
    } elsif (!$uris[2] || !length($uris[2])) {
      ($found, $u) = check_services_status_and_down(1);
    } elsif ($uris[2] ne 'health') {
      $found = 0;  
    }
    my @a  = loadavg();
    my ($s, $memscore) = meminfo();
    $h = &health($memscore, $a[1], 2);
    $buf =   "Load: " . join(" ", @a) . "\n"
           . "Memory: $s\n"
           . "Health: $h\n"
  } elsif ($uris[1] eq 'state' && $uris[2] eq 'service' && $uris[3]) {
    ($found, $u) = check_services_status_and_down(0, \%query);
    $h = 100;   # Dummy value. just make sure its > 0.
  } else {
    $found = 0; 
  }

  $h = 0 if ($u || $d);
  unless (defined($d) ) { $d = ''; }
  unless (defined($u) ) { $u = ''; }
  $buf = $buf . "$d$u";

  return $found ? ($buf, $h) : ($buf, -1);
}

sub printHash
{
  my $hash = shift;
  my $v;
  printf "Count: %d\n" , scalar keys(%$hash);
  foreach my $i ( sort keys %$hash ) {
     $v = $hash->{$i};
    printf "$i -> $v\n",
  }
}
sub health
{
  my ($mem, $load_avg, $cpu) = @_ ;
  my $h = 100 ;
#  if ( stat("/DOWN",&down_file) == 0 ) 
#  { 
#      return -1 ; 
#  }
#  load = avg[1] / 2 ;
  my $load = $load_avg / $cpu ;
  if ($load < .8 ) {
    $h-= 1;
  } elsif ($load < 1.0 ) {
    $h-= 10;
    #//  14:10:57 up 7 days, 23:29, 36 users,  load average: 9.40, 4.70, 2.06
  } elsif ($load < 1.5 ) {
    $h-= 50;
  } else {
    $h-= 90;
  }
  #/* h -= avg[1] / 2 < 1.2 * 100 ; */
  #mem = (kb_main_used % kb_main_total) * 100 / kb_main_total ;
  if ( $mem >= 95 ) {
      $h -= 80;
  } elsif ( $mem >= 80 ) {
      $h -= 50;
  } elsif ( $mem >= 50 ) {
     $h -= 25;
  } 
  if ( $h < 1 ) {
    $h = 0;
  } elsif ( $h > 100 ) {
    $h = 100;
  }
  return $h;
}
sub meminfo() {
  my %meminfo;
  my $buf = slurp($MEMINFO_FILE);
  foreach my $l (split(/\n/,$buf)) {
    $l =~ m/^(\w+):\s+(\d+).*$/;
    $meminfo{$1} = $2;
  }
#  printHash(\%meminfo);
  my $kb_swap_used =  $meminfo{'SwapTotal'} - $meminfo{"SwapFree"}; 
  my $kb_main_used = $meminfo{'MemTotal'} - $meminfo{"MemFree"}; 
  my $kb_main_total = $meminfo{'MemTotal'} ;
  my $kb_cache = $meminfo{"Buffers"} + $meminfo{"Cached"};
  my $memscore = ($kb_main_used % $kb_main_total) * 100 / $kb_main_total ;

  my $s = sprintf("%04u %04u %04u %04u %04d", $kb_main_total,
              $kb_main_used, $kb_cache, $kb_swap_used, $memscore);
  print $s if $DEBUG;
  return ( $s, $memscore ); #$meminfo{'MemTotal'},$meminfo{"MemFree"}, $meminfo{''}  )
}

1;
__END__
