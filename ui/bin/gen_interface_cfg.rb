#!/usr/bin/ruby 

require 'network_nodes'

def single_interface(nic0)
  port0 = nic0.port_name
"#
# First network interface
#
iface #{port0} inet manual
hwaddress ether #{nic0.mac_address}
pre-up /sbin/ifconfig #{port0} up 
post-down /sbin/ifconfig #{port0} down
"
end
def bonded_interface(title, bond, nic0, nic1, is_load_balancer=false)
  port0 = nic0.port_name
  port1 = nic1.port_name
  if is_load_balancer then
    hw = ''
  else
    hw = "hwaddress ether #{nic0.mac_address}"
  end
"#
# #{title} (bonded) network interface
#
iface #{bond} inet manual
#{hw}
pre-up /sbin/ifconfig #{port0} up 
pre-up /sbin/ifconfig #{port1} up 
pre-up /sbin/ifconfig #{bond} up
pre-up /sbin/ifenslave #{bond} #{port0} #{port1} 
pre-down /sbin/ifenslave -d #{bond} #{port0} #{port1} 
post-down /sbin/ifconfig #{bond} down
post-down /sbin/ifconfig #{port0} down
post-down /sbin/ifconfig #{port1} down
"
end
# Management 
def mgmt_interface(bond, ip_address, scripts)
"#
# Configure vlan4000  VLAN
#
iface vlan4000 inet static
pre-up ifup #{bond} &> /dev/null
address #{ip(ip_address)} 
netmask #{netmask(ip_address)}
vlan_raw_device #{bond}
post-up  /etc/cnu/scripts/cnu-mgmt-interface
pre-down /etc/cnu/scripts/cnu-mgmt-interface
"
end
def san_interfaces(san_interfaces)
  return '' unless san_interfaces.length > 0 
  x = san_interfaces.map { |port, ipaddr | 
    "
iface #{port} inet static
address #{ip(ipaddr)}
netmask #{netmask(ipaddr)}
post-up /etc/cnu/scripts/cnu-san-interface
pre-down /etc/cnu/scripts/cnu-san-interface
#"
  }.join('\n')
  "#
# SAN network interfaces
#
#{x}
"
end
def application_interface(title, interface, bond, ip_address, add_gateway)
  if add_gateway then
    g = "gateway #{gw(ip_address)}\n"
  else
    g = ''
  end  
      "
# Application vlan for #{title}
iface #{interface} inet static
pre-up ifup #{bond} &> /dev/null
address #{ip(ip_address)}
netmask #{netmask(ip_address)}
#{g}vlan_raw_device #{bond}
"
end 
def loadbalancer_interface(node, cluster, app_bond)
  g = ''
  bond = app_bond
  if cluster.vlan == 502 then
      bond = 'bond0'
      g = "gateway #{gw(cluster.ip_address)}\n"
  elsif cluster.vlan == 500
    scripts = "post-up /etc/cnu/scripts/cnu-chb-interface
pre-down /etc/cnu/scripts/cnu-chb-interface"
  elsif cluster.vlan == 501
    scripts = "post-up /etc/cnu/scripts/cnu-ha-interface
pre-down /etc/cnu/scripts/cnu-ha-interface"
  end
  interface = "vlan#{cluster.vlan}" 
  ip_address = cluster.ip_address

" 
# #{cluster.title}
iface #{interface} inet static
pre-up ifup #{bond}  &> /dev/null
address #{ip(ip_address)}
netmask #{netmask(ip_address)}
#{g}vlan_raw_device #{bond}
#{scripts}
"
end
def auto_interfaces(ints )

  if ints.length < 10 then
    return "#{ints.compact.join(' ')}"
  end 
    
 output = Hash.new([])
#=> [9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 23, 24, 25, 30, 32, 33, 34, 35, 40, 49, 50, 60, 61, 62, 63, 64, 65, 70, 71, 72, 73, 74, 75, 76, 80, 81, 82, 83, 84, 85, 90, 91, 92, 93, 94, 95, 100, 101, 500, 501, 502, 4000]
  ints.each do |vlan| 
      v = vlan[4..-1].to_i
      k = v/10 
      output[k] = output[k].clone << vlan
  end
  output.keys().sort.map{|k| 
    line = output[k] 
    "\nauto #{line.compact.join(' ')}"
  }.join("")
end

def write_interface_domO(node) #mgmt_ip_address , fn_prefix, mac_of_eth_0 )
  fn = output_fn(node.fn_prefix,"interfaces")


  File.open( fn,'w') {|io|
io.puts "##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
# On the local nodes we have a /etc/network/interfaces file:
# Network setup for the local machine
# #{node.fn_prefix}:/etc/cnu/configs/node/interfaces
#
#
# Bring up the following interfaces at boot
#
auto lo #{auto_interfaces(node.network_interfaces)}

#
# The loopback network interface
#
iface lo inet loopback
"
  case node.lan_nics.length 
  when 2 then 
    io.puts bonded_interface('The primary','bond0', node.lan_nics.first, node.lan_nics.last)
    io.puts mgmt_interface('bond0', node.mgmt_ip_address, node.is_load_balancer?)
  when 4 then
    if node.is_load_balancer? then
      io.puts bonded_interface('The External','bond0', node.lan_nics[0], node.lan_nics[2], true)
      io.puts bonded_interface('The Internal','bond1', node.lan_nics[1], node.lan_nics[3], true)
      io.puts mgmt_interface('bond1', node.mgmt_ip_address, node.is_load_balancer?)
    else
      io.puts bonded_interface('The primary','bond0', node.lan_nics[0], node.lan_nics[1])
      io.puts mgmt_interface('bond0', node.mgmt_ip_address, node.is_load_balancer?)
      io.puts "# Ignoring extra lan interfaces "
      io.puts "# #{node.lan_nics[2].port_name} #{node.lan_nics[2].mac_address}"
      io.puts "# #{node.lan_nics[3].port_name} #{node.lan_nics[3].mac_address}"
    end
  when 1 then
    one_nic = node.lan_nics.first
    io.puts single_interface(one_nic)
    io.puts mgmt_interface(one_nic.port_name , node.mgmt_ip_address, node.is_load_balancer?)
  else
        io.puts "# Unsupported number(#{node.lan_nics.length}) for bond"
        io.puts "# #{node.lan_nics.inspect} "
  end
  if node.san_nics.length > 0 then
    io.puts san_interfaces(node.san_interfaces)
  end 
  if node.is_load_balancer? then
   app_bond = 'bond1'
  else
   app_bond = 'bond0'
  end
  node.clusters.each { |c|  
      next if c.vlan == 4000
      if [500,501,502].member? c.vlan and node.is_load_balancer?  then
      io.puts loadbalancer_interface(node, c, app_bond)
      else
      io.puts application_interface(c.title, "vlan#{c.vlan}",app_bond, c.ip_address, (not node.is_load_balancer?() ))
      end
  }
#      io.puts "# Application vlans
# iface vlan#{c.vlan} inet static
# pre-up ifup bond0
# address #{ip(c.ip_address)}
# netmask 255.255.255.0
# gateway #{gw(c.ip_address)}
# vlan_raw_device bond0
# #"
  io.puts " "
  }
  "Write out file: #{fn}"
end

def main
    nodes = Node.find_all_physical
#@      node.find(:all, :conditions => ["node_type_id = 1 and hostname like "]).select { |a| a.active? }
    cnt = 0
    nodes.each { |n|
      begin
        #unless n.is_load_balancer? then
          write_interface_domO(n)
          cnt = cnt + 1
        #end
     rescue Object => e
      puts e
      puts e.backtrace
     end
    }
  puts "Creating interface files: #{cnt}" if $VERBOSE
end

main()
__END__
# io.puts "
# #
# # The primary (bonded) network interface
# #
# iface bond0 inet manual
#
# hwaddress ether #{node.eth0.mac_address}
# pre-up /sbin/ifconfig eth0 up 
# pre-up /sbin/ifconfig eth1 up
# pre-up /sbin/ifconfig bond0 up
# pre-up /sbin/ifenslave bond0 eth0 eth1
# pre-down /sbin/ifenslave -d bond0 eth0 eth1
# post-down /sbin/ifconfig bond0 down
# post-down /sbin/ifconfig eth0 down
# post-down /sbin/ifconfig eth1 down

# io.puts " 
# #
# # Configure Management vlan4000  VLAN
# #
# iface vlan4000 inet static
# pre-up ifup bond0
# address #{ip(node.mgmt_ip_address)} 
# netmask 255.255.254.0  
# vlan_raw_device bond0
# ### post-up  /etc/cnu/scripts/cnu-mgmt-interface
# ### pre-down /etc/cnu/scripts/cnu-mgmt-interface
# "
# The vlan4000 network interface
# iface vlan4000 inet static
# pre-up ifup eth0 
# address 172.16.0.111 
# netmask 255.255.254.0  
# vlan_raw_device eth0 
# ### post-up  /etc/cnu/scripts/cnu-mgmt-interface
# ### pre-down /etc/cnu/scripts/cnu-mgmt-interface
#
# # The First SAN interface
# iface eth2 inet static
# address 198.51.100.141
# netmask 255.255.255.0
# post-up /etc/cnu/scripts/cnu-san-interface
# pre-down /etc/cnu/scripts/cnu-san-interface
#
# # The Second SAN interface
# iface eth3 inet static
# address 198.51.100.142
# netmask 255.255.255.0
# post-up /etc/cnu/scripts/cnu-san-interface
# pre-down /etc/cnu/scripts/cnu-san-interface
