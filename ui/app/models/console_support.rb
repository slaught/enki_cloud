#!/usr/bin/ruby 


require 'rubygems'
require 'active_record'
require 'active_support'

require 'date'
require 'ipaddr'
VERBOSE = true

require 'network_nodes'

def help_create 
  puts %Q(
  create cluster
  Cluster.create_cluster(p_name,p_desc, p_vlan, p_ip_range, calculate_fw_mark=true)
  if not load_balanced, set to false then create
  Node.create_node(serial_no, node_type, os_version, name, location) 
)

end

class Node < ActiveRecord::Base
# TODO: delete this method after Jan 1st 2011
# reason: this is diverging from the primary create-node_by_id
  def self.create_node(serial_no, node_type, os_version, name, dc_id, mgmt_ip=nil) 
    nt = NodeType.find_by_name(node_type)
    raise NodeException.new('Unknown node type') if nt.nil?
    dc = Datacenter.find_by_name(dc_id)
    #
    mgmt_cluster = Cluster.find_mgmt_cluster_by_location(dc.name)
    aNode = create({:serial_no => serial_no, :node_type => nt, :hostname => name,
        :datacenter => dc ,:os_version => os_version }) 
    return aNode if aNode.id.nil?
    aNode.mgmt_ip_address = Cluster.add_node_to_cluster(mgmt_cluster, aNode, mgmt_ip)
    # mgmt_cluster.add_node(aNode, mgmtip)
    aNode
# FIXME: add options for these
#     Column      |  Type   |                        Modifiers                        
# model_id        | integer | 
# serial_console  | text    | 
# os_version_id   | integer | 
  end
  public
  def add_lan_nics(macs, port_names )
    macs.zip(port_names).map{|x| add_lan_nic(*x) }
  end
end

class Service < ActiveRecord::Base

  def self.mk_services(name, desc, fqdn, ha_ip, ports)
      svc = Service.find_all_by_name(name)
      if svc.length == ports.length then
         return svc
      elsif svc.length == 0
        ports.map do |l, s, u|
           self.mk_service(name, desc, fqdn, l, s, ha_ip, u)
        end
      else
        raise Exception.new("Can't ues quick method as you fucked it up")
      end
  end
  def self.mk_service(name, desc, fqdn, lport, sport, ha_ip, uri_schema)
      if ha_ip =~ /^209.60.186/ then
        avail = 'public'
      else
        avail = 'campus'
      end
      Service.create({ :local_port => lport, :service_port => sport, :name => name,
          :url => "#{uri_schema}://#{fqdn}", :availability => avail, :description => desc,
          :ip_address => ha_ip, :not_unique => ip2dec(ha_ip)
          })
  end
end

class CnuMachineModel < ActiveRecord::Base
  def self.create_virtual(cpus, ram, desc) 
    create({:cpu_cores => cpus, :megabytes_memory => ram, :model_no => desc, 
        :manufacturer=> 'CNU Xen Virtual Machine' }) 
  end
end

class Disk < ActiveRecord::Base
  def self.help
    "self.create_xen_disk(volume,mount ='/data',size=1)\nself.create_iscsi(volume,mount_point='/data',size=1)"
  end
end
