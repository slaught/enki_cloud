#!/usr/bin/ruby 

require 'network_nodes'

LBSVC_FILE= "lb.services" 

def find_services
    services = []
    portfwd = []
    ClusterConfiguration.find(:all).each { |rec|
      if  rec.fw_mark.nil? or rec.ha_ip_address.nil? or rec.port.nil?  or rec.proto.nil? then
        next
      end
      a = [ rec.fw_mark,
            'vlan4000',
            rec.ha_ip_address , 
            rec.port , 
            rec.proto
          ]
      if rec.ha_ip_address =~ /^209.60.186/ then
          vlan =  "vlan502" 
      else
          vlan =  "vlan501" 
      end
      a[1] = vlan
      
      if rec.is_lb  then
        services  <<  a.map {|e| e.to_s.strip() }
      else
        a << ip(rec.node_ip)
        portfwd  <<  a.map {|e| e.to_s.strip() }
      end
  }
  [services.uniq, portfwd.uniq ]
end 
def format(svc)
  svc.map{ |arr|
     "\t\"#{arr.join(':')}\""
  }
end

def write_lvscfg(fn, lb_data, pfw_data)
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
# And on the LB /etc/cnu/node/#{fn} 
# Network services/ports opened for loadbalancing 
#
# Syntax: (\"LVS_ID:Interface:Global_HA_IP:Global_HA_Port:Protocol\")
# "
      io.puts "LVS_MANGLE_SERVICES=( "
      io.puts format(lb_data).join("\n")
      io.puts ")"

      io.puts %Q(#
# Syntax: ("LVS_ID:Interface:Global_HA_IP:Global_HA_Port:Protocol:Internal_IP")
#)
#        "8888:vlan502:10.10.10.27:80:tcp:10.1.10.101"
#         "8888:vlan502:10.10.10.27:443:tcp:10.1.10.101"
      io.puts "PORTFW_MANGLE_SERVICES=( "
      io.puts format(pfw_data).join("\n")
      io.puts ")"
  }
end

def main
    svc, pfwd  = find_services()
#    lb_data = format_svc(svc)
#    puts data.inspect
    write_lvscfg(LBSVC_FILE, svc, pfwd)
end

main()
