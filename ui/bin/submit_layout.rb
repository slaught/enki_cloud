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
require 'cnu/enki/config_layout'
include CNU::Enki::ConfigLayout

def main
    dirs = ['ha.d','node','downpage','lvs','uuid','xen','dns','space','asa']
    puts "Loading #{ENV['RAILS_ENV']} environment (Rails #{Rails.version})"
    rc = print_git_commands(dirs)
    puts rc
    puts `rc`

end

main
__END__

