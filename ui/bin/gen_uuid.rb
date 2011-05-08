#!/usr/bin/ruby 

require  'fileutils'
require 'network_nodes'

def write_os(node,prefix)
  fn = "#{prefix}/OS_VERSION" 
  puts "Write out file: #{fn}" if $VERBOSE
  if node.os_version.nil? then
    puts "Warning: Failed to write #{node.hostname} has no os_version" if $VERBOSE
    return
  end
  File.open( fn,'w') {|io|
      io.puts %Q(OS_VERSION="#{node.os_version.distribution}")
      io.puts %Q(KERNEL="#{node.os_version.kernel}")
      io.puts %Q(HOSTNAME="#{node.fqdn}")
  }
  FileUtils.chmod 0644, fn
end

def main
    nodes = Node.find_all_physical
    FileUtils.rm_r('uuid') if File.directory?("uuid")
    cnt = 0
    nodes.each { |n|
      h = n.fn_prefix
      begin
        if File.directory?("node/#{h}") then
          uuid_dir = "uuid/#{n.uuid.downcase}"
          FileUtils.mkdir_p(uuid_dir, :mode => 0755)
          File.symlink("../../node/#{h}", "#{uuid_dir}/#{h}")
          write_os(n,uuid_dir)
          cnt = cnt + 1
        else
          puts "no files for #{h}" if $VERBOSE
        end 
      rescue Object =>e
        puts e if $VERBOSE
      end
    }
    puts "Creating uuid bootstrapt: #{cnt}/#{nodes.length}" if $VERBOSE
end

main()


