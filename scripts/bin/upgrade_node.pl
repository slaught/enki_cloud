#!/usr/bin/perl -w

use strict; 
use Getopt::Declare;
use File::Basename;
use File::Path qw(make_path);
use vars qw( $masternode $node $force $colo $baseimg $template);
$force = 0;
my $domain = 'example.com';
my $spec= q(

		--master <master>		Master node  [required]
												  {$::masternode = $master; }
		--node <n>		      Node to upgrade [required]
									        {$::node = $n; }
		--colo <c>		      Node to upgrade [required]
									        {$::colo = $c; }
		--force             Immediate down node
									        {$::force= 1; }

);

my $rsync = 'rsync -avPS' ;
my $mount = 'mount';

if (0) {
$baseimg = '/xen/base-images/32bit/Node-Enki-Lenny-i386.img'; 
$template = '/xen/domains/%s/disk.img' ;
} else {
$baseimg = './base/Node-Enki-Lenny-i386.img'; 
$template = './xen/%s/disk.img' ;

}

sub create_new_disk_image
{
  my $n = shift;
  my $dest = shift; # sprintf $template, $n;
  my $cmd = "$rsync $baseimg $dest";
  print $cmd;
  print qx($cmd);
  #  `rsync -avPS /xen/base-images/32bit/Node-Enki-Lenny-i386.img /xen/domains/<node>/disk.img.new `
  if ( -e $dest ) {
    return 1;
  } else {
    print "Error creating $dest\n";
    return 0;
  }
}
sub wait_for_node
{
  return if $force;
  print "Waiting for node to stop\n";
  sleep  5;
}
sub wait_on_xen
{
  my $n = shift;
  my $cmd = "sudo xm list |grep $n";
  my $timeout = 0;
  print "waiting on xen to stop node";
  my $x ;
  do {
    $x = `$cmd`;
    sleep $timeout;
    $timeout = 2 * ($timeout + 1);
    print ".";
  } while ( $x =~ m/$n/ );
  print "stopped\n";
}
sub down_node
{
  my $n = shift;
  my $dc = shift;

  print qx(ssh $n.$dc /enki/bin/downnode);
  &wait_for_node;
  $_ = `ssh $n.$dc /enki/bin/nodestatus`;
  unless ( m/node\s+is\s+down/ ) { return 0; }
  $_ = qx(ssh $n.$dc sudo /etc/enki/scripts/dsh-wrapper shutdown -h);
  &wait_on_xen($n);
}
sub is_mounted
{
  my $dir = shift;
  if (! defined($dir)) { croak("FIAIL!") }; 
  if ( ! -d $dir ) { die("Erroring no $dir"); }
  my (undef,undef,undef,$cnt,undef) = stat($dir) ; 
  if ($cnt <= 2 ) {
      return 0;
  } else {
      return 1;
  }
}
sub unmount
{
  my $subdir = shift;
  if (&is_mounted($subdir)) {
      print `sudo umount $subdir`;
  }
}
sub mount
{
  my $disk = shift;
  my $subdir = shift;
  my $cmd = "sudo mount -oloop $disk $subdir";

  &unmount($subdir); 

  print `$cmd` ; # print $cmd ;
  if (-d "$subdir/etc" ) {
    return 1;
  } else {
    print "These are not the droids you are looknig for. They are blackberries\n";
    return 0;
  }
}
sub cp
{
  my $src = shift;
  my $dest = shift;
  my $src_path = shift;
  my $dest_path = dirname($src_path);
  my $cmd = "sudo $rsync $src/$src_path $dest/$dest_path";
  print "Running $cmd\n";
  print `$cmd` ; 
  if ( -d "$dest/$src_path" ) {
    return 1;
  } else {
    return 0;
  }
}
sub mkpath 
{
  my $fn = shift;
  my $d = dirname $fn;
  return &mkdir($d); 
}
sub mkdir
{
  my $dir = shift;
  return 1 if ( -d $dir ) ;

  print `sudo mkdir -p $dir`;
  if ( -d $dir ) { return 1; }
  else           { return 0; }
  
}

sub has_disk
{ my $disk = shift;
  print "Checking for existing disks: $disk\n" ;
  if ( -e $disk && ! -e "$disk.old" ) { 
      return 1; 
  } else { 
      print "Error backup disk exists. Clean up first.\n";
      print " Run % rm $disk.new $disk.old\n";
    return 0; 
  }
}


sub check_xen
{
  my ($node, $colo) = @_;
  my $fn = "/etc/xen/$node.$colo.cfg" ;
  print "Checking xen for $node.$colo\n";

  if ( -e $fn ) { 
      my $x = `grep -l 2.6.26 $fn`;
      return 1 if ($x =~ m/$fn/ );
  } 
  return 0; 
}
sub swap_disks
{
  my $old = shift;
  my $new = shift;
  my $bak = "$old.old";

  `mv $old $bak`;
  `mv $new $old`;
  if ( -e $old && -e $bak && ! -e $new ) {
    return 1;
  }
  else { 
    print "Error moving $new to $old\n";
    return 0;
  }
}
#sub keyscan_new_node
#{
#  my $node = shift;
#  my $colo = shift;
#
#  my $x = `ssh-keyscan -t rsa, dsa $node.$colo $node.colo.example.com`;
#
#  return 0;
#
#}
sub  get_warsync_master_key
{
  my $master = shift;
  my $serverkey = `ssh $master cat /etc/warsync/server-key.pub`;
  
  return $serverkey;
}
sub config_warsync_client
{
  my $master = shift;
  my $node = shift;
  my $colo = shift;
  my $subdir = shift;
  my $hostname = "$node.$colo";

  my $key = "$subdir/etc/warsync/client-key";
  &mkpath($key);
  my $pubkey = "$key.pub";
  `ssh-keygen -N '' -t rsa -q -b 4096 -C 'root\@$hostname.$domain' -f $key `;
  if ( ! -e $key || ! -e $pubkey ) {
    print "Failed to make $key\n";
    return 0;   
  }
  my $conffile = "$subdir/etc/warsync/client.conf";
  &mkpath($conffile);
  open(my $conf, "> $conffile ")
        or die("could not write $conffile : $!");
  print $conf <<EOF;
SERVER = $master
PORT   = 22
EOF
  close($conf);
  my $authkeys = "$subdir/root/.ssh/authorized_keys";
  &write_out_client_authorized_keys($master, $authkeys);
}

sub write_out_client_authorized_keys
{
  my $master = shift;
  my $authkeys = shift;

  unless(  &mkpath($authkeys)        ) { return 0; };

  my $server_public_key = &get_warsync_master_key($master);

  open(my $ak, ">> $authkeys") 
        or die("could not write /root/.ssh/authorized_keys: $!");
  print $ak <<EOF;
# warsync-client-push command is used for Warsync client
command="/usr/sbin/warsync-client-push",no-port-forwarding,no-X11-forwarding,no-agent-forwarding $server_public_key
EOF
    close($ak);
  return 0;
}
sub start_node
{
  my $n = shift;
  my $c = shift;
  print `sudo xm create $n.$c.cfg `;
  print "waiting for startup...\n";
  sleep 5;
  return 0;
}

sub sync_master
{ 
  my ($master,$node, $colo) = @_ ;

  my $warcmd ="sudo warsync --debian -a --skip-cmds --client=$node.$colo";
  print "From $master do the following\n$warcmd\n";
  my $cmd = "ssh $master $warcmd";
  print "$cmd\n";
  
  return 0;
}
sub main
{
  my $args = new Getopt::Declare $spec;
  unless ($args) { exit(-1); }
  print "Upgrading $node in cluster $masternode\n";
  my $rc = 0; 
  my $new_disk = sprintf $template . ".new", $node;
  my $old_disk = sprintf $template, $node;

  unless(  &create_new_disk_image($node,$new_disk)    ) { exit 1;}
  unless(  &has_disk($old_disk)                       ) { exit 7;}
  unless(  &down_node($node, $colo)                   ) { exit 2;}
  my $olddir = "/mnt/old$node";
  my $newdir = "/mnt/new$node";
  unless(  &mkdir($olddir)                     ) { exit 30;}
  unless(  &mkdir($newdir)                     ) { exit 31;}
  END { 
    my $x = $?;
    &unmount($olddir) if ($olddir && -d $olddir); 
    &unmount($newdir) if ($newdir && -d $newdir); 
    $? = $x;
  }
  unless(  &mount($old_disk, $olddir)          ) { exit 4;}
  unless(  &mount($new_disk, $newdir)          ) { exit 5;}
  unless(  &cp($olddir, $newdir , 'etc/enki/configs/node')  ) { exit 10;}
  unless(  &cp($olddir, $newdir , 'var/service')           ) { exit 11;}
  unless(  &cp($olddir, $newdir , 'var/log/enkiapp')        ) { exit 11;}

  unless(  &check_xen($node, $colo)                        ) { exit 41;}
  #
  unless(  &config_warsync_client($masternode,$node,$colo,$newdir)  ) { exit 44;}

  unless(  &unmount($olddir)                   ) { exit 13; }
  unless(  &unmount($newdir)                   ) { exit 14; }
  END { 1;}
  unless(  &swap_disks($old_disk, $new_disk)             ) { exit 42;}
  unless(  &start_node($node, $colo)              ) { exit 50; }
  unless(  &sync_master($masternode,$node, $colo)              ) { exit 60; }

  print "End\n";

  #  `rsync -avPS /xen/base-images/32bit/Node-Enki-Lenny-i386.img /xen/domains/<node>/disk.img.new `
}


&main;
__END__

