#!/usr/bin/ruby 

# # Syntax: ('Src_IP:Src_Port:Dst_IP:Dst_Port:Protocol:Local_Interface')
# #
# NET_FILTER=(
#         "239.0.0.25:8848:::udp:vlan500"         # Multicast Corosync (Pacemaker)
#         "224.0.0.81:5405:::udp:vlan500"         # Multicast LVS Connection Sync
# )

#
# defaults for all nodes for vlan4000
#   snmp - 161 udp,tcp
#   ssh  - 22 tcp
#   http - 80 tcp 
#        [nil, nil, 'tcp', 161, 'vlan4000'],
#        [nil, nil, 'udp', 161, 'vlan4000'],
#        [nil, nil, 'tcp', 22, 'vlan4000'],
#        [nil, nil, 'tcp', 80, 'vlan4000'],

require 'network_nodes'

def write_netcfg(node) 
  fn = output_fn(node.fn_prefix,"net.services" )
  return unless node.node_type.can_has_net_service?
  File.open( fn,'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
# #{node.fn_prefix}:/etc/cnu/configs/node/net.services 
#
# Network services/ports opened for the local machine via cnu-firewall
# Syntax: ('Global_HA_IP:Global_HA_Port:Protocol:Local_Port:Local_Interface')
# "
      io.puts "NET_SERVICES=( \n#{node.net_services}\n)\n"
      if node.is_load_balancer? then
      io.puts %Q(#
# Syntax: ('Src_IP:Src_Port:Dst_IP:Dst_Port:Protocol:Local_Interface')
#
NET_FILTER=(
        "::239.193.0.25:5405:udp:vlan500"               # Routed Multicast Corosync (Pacemaker)
        "::224.0.0.81:8848:udp:vlan500"                 # Local Multicast LVS Connection Sync
        "10.15.254.16/28::::ipencap:vlan500"            # LVS Tunnel Route (OBR)
        "10.15.254.0/28::::ipencap:vlan500"             # LVS Tunnel Route (NUT)
)
)
      end
  }
  "Write out file: #{fn}"
end
def main
    nodes = Node.find_all_active
    cnt = 0
    nodes.each { |n|
      begin
        x = write_netcfg(n)
        cnt = cnt + 1
      rescue Object =>e
        puts e
      end
    }
    puts "Creating net.services #{cnt}" if $VERBOSE
end

main()
