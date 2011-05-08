#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class Scs  

protected
def Scs.serial_config(node)
   return nil if node.model.nil? 
   return node.model.serial_console 
end
def Scs.find_hosts(scs_node)
    attached_hosts = SerialConsole.find_all_by_scs_id(scs_node.id)
    if attached_hosts.length < 1 then
      puts "Warning: No hosts attached to #{scs_node.fn_prefix}" if $VERBOSE
      return []
    end
    attached_hosts.map{|n|
      config = serial_config(n.node)
      unless config.nil? then 
        [n.port, n.node.fn_prefix , config].flatten
      else  
        puts "Warning: Host #{n.node.fn_prefix} machine has no serial config" if $VERBOSE
        nil
      end
    }.compact
end
protected
def Scs.write_scs_ports(filename, node) 
  fn = output_fn(filename, node.fqdn)
  return unless node.node_type.is_serial_console?
  data = find_hosts(node)
  return if data.empty? 

  File.open( fn,'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
##################################################################
# 
#{version_string()} 
# #{node.fn_prefix}:/etc/cnu/configs/#{fn}
#
# Serial Console ports and config 
# Syntax: ('port:attached host:baud rate:dte/dce:flow control')
"
      x  = format_bash_array(data)
      io.puts "SERIAL_PORTS_CFG=( \n#{x}\n)\n"
  }
end

public
def Scs.generate(filename)
    t = Time.now()
    nodes = Node.find_all_active
    cnt = 0
    nodes.each { |n|
      begin
        if n.node_type.is_serial_console?
          x = write_scs_ports(filename, n) 
          cnt = cnt + 1
        end
      rescue Object =>e
        puts e
      end
    }
    puts "Creating scs.ports #{cnt}" if $VERBOSE
    print_runtime(t,'Serial Console Servers')
end

end

end # end module
