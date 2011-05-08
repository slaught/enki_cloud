#!/usr/bin/ruby

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
#$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

$verbose = false
ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?

require 'config/environment'


def collect_the_xens(dc)
  #xens = Node.active.physical.find(:all, :conditions => ["hostname like ?", "%xen%"]).map {|n| n.fqdn }
  xens = Node.physical.find_all_active_by_datacenter(Datacenter.find_by_name(dc), :conditions => ["hostname like ?", "%xen%"]).map{ |n| n.fqdn }

  xens.each { |x| puts `#{RAILS_ROOT}/bin/collect_xen.sh #{x}` }
end

def main
  if ARGV.empty?
    puts "Usage: collect_all_xen DATACENTER"
  else
    collect_the_xens(ARGV[0])
  end
end

main()
__END__
