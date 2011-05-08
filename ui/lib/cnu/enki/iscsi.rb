#!/usr/bin/ruby 

require 'digest/md5'

module CNU::Enki

include CNU::Enki::ConfigLayout

class Iscsi 

public
def self.generate()
    t = Time.now()
    new().generate() 
    print_runtime(t,'ISCSI')
end
def generate()
    nodes = SanNode.find(:all).map{|sn| sn.node } 
    total = 0
    cnt = 0
    nodes.each { |n|
      begin
        x = iscsi_node(n) 
        if x then 
           cnt = cnt + 1 
        end
        total = total + 1
      rescue Object =>e
        puts e
      end
    }
    puts "Creating #{filename} #{cnt}/#{total}"  if $VERBOSE
end
def iscsi_node(node) 
  san_nics = node.san_nics 
  return if san_nics.empty? 
  fn = output_fn(node.fn_prefix, 'ifaces') 
  san_nics.each {|nic|
      write_iface_file(fn, nic, node.fn_prefix)
  }
  write_initiator( node) 
  write_san_paths(node)
end
####################################################################3
def write_san_paths(node)
  file_name = 'san.paths'
  fn = output_fn(node.fn_prefix,file_name)
  data = node.san_paths
  return if data.length == 0 
  File.open(fn,'w') {|io|
      io.puts "
# #{node.hostname}:/etc/cnu/configs/node/#{file_name}
## DO NOT EDIT OR REMOVE THIS FILE!
#
# Local ISCSI network path information for the local machine
# Syntax: ('Local_Interface:SAN_IP')
#
"
  io.puts "ISCSI_PATHS=( \n#{format_bash_array(data)}\n)\n"
  }
  true
end
def write_initiator(node) 
  file_name = 'initiatorname.iscsi'
  fn = output_fn(node.fn_prefix,file_name)
  iqn = node.iqn
  return if iqn.nil? || iqn.length == 0
  File.open(fn,'w') {|io|
      io.puts "
# #{node.hostname}:/etc/iscsi/#{file_name}
## DO NOT EDIT OR REMOVE THIS FILE!
## If you remove this file, the iSCSI daemon will not start.
## If you change the InitiatorName, existing access control lists
## may reject this initiator.  The InitiatorName must be unique
## for each iSCSI initiator.  Do NOT duplicate iSCSI InitiatorNames.
InitiatorName=#{iqn} 
"
  }
  true
end
def write_iface_file(dir, nic, hostname)
  return false unless nic.network_type == 'san'
  mkdir_p(dir) unless Kernel.test('d', dir)
  File.open(File.join(dir,nic.port_name),'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
##################################################################
# 
#{version_string()} 
# #{hostname}:/etc/cnu/configs/node/ifaces/#{nic.port_name}
#
# iSCSI interface config for #{nic.port_name} 
# Set the iscsi transport/driver to use 
iface.transport_name = tcp
# To bind by network interface name 
iface.net_ifacename = #{nic.port_name} 
# To bind by hardware address set the NIC's MAC address to iface.hwaddress example:
# iface.hwaddress = #{nic.mac_address}
"
  }
  true
end

  def self.generate_name(prefix, hostname, number, urandom='/dev/urandom', read_length=16)
    self.new.generate_name(prefix, hostname, number, urandom, read_length)
  end

  def generate_name(prefix, hostname, number, urandom='/dev/urandom', read_length=16)
    h,dc, *other  = hostname.split('.') 
    if dc.nil? then
      raise Exception.new("ERROR: Failed to generate iqn for '#{hostname}' no datacenter defined")
    end
    "#{prefix}:#{dc}.#{h}"
  end


end #end class
end # end module
