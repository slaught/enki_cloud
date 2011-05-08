
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require File.expand_path(File.dirname(__FILE__)) + '/test_helper'

Sham.reset 
ActiveRecord::Base.establish_connection(:test )
fixture = %Q(locations sans services clusters nics database_clusters database_names 
    cnu_machine_models nodes cluster_nodes cluster_services database_cluster_database_names
    san_nodes pdus network_switch_ports node_nics xen_mappings disks node_disks
  ).split(' ').reverse.join(";DELETE FROM ")
ActiveRecord::Base.connection.execute "DELETE FROM #{fixture};"
#################

def make_xen_domO(name)
  n = Node.make(:physical,:hostname => name)
  n.nics << Nic.make(:san)
  n.nics << Nic.make(:san)
  n.nics << Nic.make(:lan)
  n.nics << Nic.make(:lan)
  n
end

  def make_active_cluster(load_balanced=true)
     c = Cluster.make
     s = Service.make(:local_port => nil)
     c.services << s
     s = Service.make
     c.services << s
     n = Node.make(:virtual)
      c.add_node(n)
     n = Node.make(:virtual)
      c.add_node(n)
    c
  end
  def make_db_cluster(hash={})
     s = Service.make
     config = DatabaseConfig.make
     DatabaseCluster.make(hash.merge({:service => s, :database_config => config})  )
  end

make_san_node

make_active_cluster
make_active_cluster
make_db_cluster

Service.make(:name => 'jabber',:url=>'xmpp://jabber.example.com')
Service.make(:url  => 'https://www.example.com')
Service.make(:local_port => nil)
Service.make(:ip_address => '10.10.10.1')
Service.make(:ip_address => '209.60.186.24')

s = San.make 
n = make_san_node
node = Node.make(:physical) 
#assert_no_difference('SanNode.count',"Fail to add node with no san connections") do
#    xhr( :post, :add_node, {  :id => @san.id  ,:node => {:node_id => @node.id}} )
#    assert_response :success
#    assert_template '_node_list'
#    assert_not_nil flash[:warning]
#    assert_match /Error node has no nics/, flash[:warning]
#end
CnuMachineModel.make 
Node.make(:virtual)
dc = Datacenter.find(:first)
cluster = Cluster.make(:cluster_name => "mgmt_#{dc.name}",:vlan => 4000)
DatabaseConfig.make
d = DatabaseName.make

XenMapping.make
Service.make
Pdu.make
Node.make :virtual

#OsVersion.make
#Distribution.make(:name => Sham.tag)

Service.make
CnuMachineModel.make
Bootstrap.make
