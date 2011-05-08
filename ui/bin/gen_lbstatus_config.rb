#!/usr/bin/ruby 

require 'network_nodes'

def main
    clusters = Cluster.find_all_active 
    lvs_cluster_info = clusters.map { |c|
      generate_lvs_cluster(c)
    }
    # prepend a comment to the array 
    lvs_cluster_info.unshift(
        ['# FW MARK ', ' Cluster Desc ',' Services (type,urn schema,HA name, localport)']
    )
    write_file(lvs_cluster_info,'|', "ha.d/lbstatus-lvs_clusters")
    lvs_node_info = []
    clusters.each {|c|
      a = generate_lvs_nodes(c) 
      lvs_node_info.concat(a)
    }
    # prepend a comment to the array 
    lvs_node_info.unshift(['# Node IP ', ' MGMT IP ',' FW MARK ',' Description/hostname'])
    write_file(lvs_node_info,':', "ha.d/lbstatus-lvs_nodes") 
end

# 
#127.0.31.1 | Description | (desc1, https://, www4.example.com, 44301); (frontend, http://, www.example.com, 8001)
#127.0.31.2 | Description | (desc3, https://, www3.example.com, 1234); (SMTP, smtp://, www2.example.com, 2501)
#
def generate_lvs_cluster(c)
  svc = c.services.map  { |s|
      [s.name, "#{s.ha_protocol}://", s.ha_hostname, s.localport ].join(', ') 
  }
  [dec2ip(c.fw_mark), c.description, svc.map { |s| "(#{ s })" }.join('; ') ]
end


# Node IP : MGMT IP : FW MARK : Description
# 192.168.13.101 : 172.16.0.45 : 127.0.32.1 : Batch Node #1
# 192.168.13.102 : 172.16.0.46 : 127.0.32.1 : Batch Node #2
# 192.168.13.103 : 172.16.0.47 : 127.0.32.1 : Batch Node #3
# 192.168.13.104 : 172.16.0.48 : 127.0.32.1 : Batch Node #4
# 192.168.13.105 : 172.16.0.49 : 127.0.32.1 : Batch Node #5
# 192.168.13.106 : 172.16.0.50 : 127.0.32.1 : Batch Node #6
# 192.168.13.107 : 172.16.0.51 : 127.0.32.1 : Batch Node #7
# 192.168.13.108 : 172.16.0.52 : 127.0.32.1 : Batch Node #8
# 192.168.13.109 : 172.16.0.53 : 127.0.32.1 : Batch Node #9
#
# 192.168.10.101 : 172.16.0.44 : 127.0.32.1 : Web Node #1 :
#
# 192.168.11.101 : 172.16.0.43 : 127.0.32.1 : API Node #1 :
# 192.168.11.102 : 172.16.0.42 : 127.0.32.1 : API Node #2 :
# 192.168.11.103 : 172.16.0.41 : 127.0.32.1 : API Node #3 :
# 192.168.11.104 : 172.16.0.40 : 127.0.32.1 : API Node #4 :
# 
def generate_lvs_nodes(c)
  dcnut = Datacenter.find_by_name("nut")
  svc = c.cluster_nodes.map do |cn|
     if cn.node.is_server? and cn.node.datacenter == dcnut then
     [ip(cn.ip_address), ip(cn.node.mgmt_ip_address), dec2ip(cn.cluster.fw_mark), cn.node.hostname ]    
    else
      nil
    end
  end.compact
#########################################################33
end

def write_file(array, sep, fn) 
  return if array.nil? or array.empty?
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') do |io|
      io.puts \
"##################################################################
########       THIS FILE WAS AUTOMATICALLY GENERATED   ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
"
    array.each {|a|
        io.puts a.join(" #{sep} ")
    }
  end
end


main()
