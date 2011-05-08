#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class HpSwitchLabels

def find_hosts(sw_node)
    attached_hosts = NetworkSwitchPort.find_all_by_switch_id(sw_node.id)
    if attached_hosts.length < 1 then
      puts "Warning: No hosts attached to #{sw_node.fn_prefix}" if $VERBOSE
      return []
    end
    attached_hosts.map{|n|
      [n.port, n.node.fn_prefix, n.switch.fn_prefix]
    }.compact
end

def write_sw_ports(filename, node) 
  fn = output_fn(node.fn_prefix, filename) 
  return unless node.node_type.is_switch?
  data = find_hosts(node)
  return if data.empty? 

  File.open( fn,'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
##################################################################
# 
#{version_string()} 
# #{node.fn_prefix}:/etc/cnu/configs/node/#{filename}
#
# Network Switch Ports outlets 
# Syntax: ('port:label/attached hostname:pdu hostname')
"
      x  = format_bash_array(data)
      io.puts "SWITCH_LABEL_CFG=( \n#{x}\n)\n"
  }
  true
end

public
def self.generate(filename)
      new().generate(filename) 
end
def generate(filename)
    t = Time.now()
    nodes = Node.active 
    total = 0
    cnt = 0
    nodes.each { |n|
      begin
        if n.node_type.is_switch?
          x = write_sw_ports(filename, n) 
          if x then 
            cnt = cnt + 1 
          end
          total = total + 1
        end
      rescue Object =>e
        puts e
      end
    }
    puts "Creating #{filename} #{cnt}/#{total}"  if $VERBOSE
    print_runtime(t,'HP Switch Labels')
end

end

end # end module
