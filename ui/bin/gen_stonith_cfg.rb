#!/usr/bin/ruby 

require 'network_nodes'


def format(list)
  list.map{ |arr|
     "\t\"#{arr.join(':')}\""
  }
end

def chk_pdus( host, length)
  return true if length == 1 
  if length.nil? or length < 1 then
    puts "Warning: no pdus assigned to #{host}" if $VERBOSE
    return false
  end
  if length > 1 then 
    puts "Error: too many pdus for #{host}. only 1 supported"
    return false
  end 
end

def find_loadbalancers
    lb = []
    nt = NodeType.find_by_name('load balancer')
    Node.find_all_by_node_type_id(nt).each  { |rec|
        if chk_pdus( rec.fn_prefix, rec.pdus.length)  then 
          pdu = rec.pdus.first 
          lb <<  [ rec.fqdn, ip(pdu.pdu.mgmt_ip_address), pdu.outlet_no ]
        end
    }
    lb.uniq!
    if lb.length < 3 then
      puts "Error: not enough load balancers with pdus. Found only #{lb.length}!" 
    end
    lb
end 

#def data
#                "testbox01.abc:172.16.8.84:1"     # Load1.abc 
#                "load2.abc:172.16.8.84:1"     # Load2.abc 
#                "load3.abc:172.16.8.84:1"     # Load3.abc 
#                "load4.abc:172.16.8.84:1"     # Load4.abc 
#end

def write_cnu_stonith_cfg(fn,data)
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') {|io|
      io.puts %Q(
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
# CNU_APC_Stonith Configuration File
#
# Load the SNMP authorization (if we are authorized)
cnu_stonith_auth=/etc/cnu/keys/cnu-stonith.auth
[ -r "$cnu_stonith_auth" ] && . "$cnu_stonith_auth"
 
# Syntax: ("Hostname:PDU MGMT IP:Outlet")
)
      io.puts "STONITH_NODES=("
      io.puts data.join("\n")
      io.puts ")"

  }
end

def main
    svc  = find_loadbalancers()
    data = format(svc)
    puts "Creating #{data.length} stonith nodes" if $VERBOSE
    fn = "ha.d/lb_heartbeat_stonith.cfg" 
    write_cnu_stonith_cfg(fn,data)
end

main()

