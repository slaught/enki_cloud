#!/usr/bin/ruby 

require 'network_nodes'

def main
    nodes = Node.find_all_physical
    cnt = 0
    nodes.each {|n|
      begin
       x = write_udev(n)
       cnt = cnt + 1
      rescue Object => e
        puts e
      end
    }
    puts "Creating udev.rules #{cnt}" if $VERBOSE
end

def write_udev(node)
  fn = output_fn(node.fn_prefix,"udev.rules")
  data = node.nic_udev_rules
  return if data.empty?
  File.open(fn, 'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
# You can modify it, as long as you keep each rule on a single line.
# MAC addresses must be written in lowercase.
# 
# "
      io.puts node.nic_udev_rules.join("\n")
  }
  "Write out file: #{fn}"
end


main()
