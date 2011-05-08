#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class PduLabels

def find_hosts(pdu_node)
    attached_hosts = Pdu.find_all_by_pdu_id(pdu_node.id)
    if attached_hosts.length < 1 then
      puts "Warning: No hosts attached to #{pdu_node.fn_prefix}" if $VERBOSE
      return []
    end
    attached_hosts.map{|n|
      [n.outlet_no, n.node.fn_prefix, n.pdu.fn_prefix]
    }.compact
end

def write_pdu_ports(filename, node) 
  fn = output_fn(node.fn_prefix, filename) 
  return unless node.node_type.is_pdu? 
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
# PDU outlets 
# Syntax: ('outlet:label/attached hostname:pdu hostname')
"
      x  = format_bash_array(data)
      io.puts "PDU_LABEL_CFG=( \n#{x}\n)\n"
  }
  true
end

public
def self.generate(filename)
      new().generate(filename) 
end
def generate(filename)
    t = Time.now()
    nodes = Node.find_all_active
    total = 0
    cnt = 0
    nodes.each { |n|
      begin
        if n.node_type.is_pdu?
          x = write_pdu_ports(filename, n) 
          
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
    print_runtime(t,'PDU Labels')
end

end

end # end module
