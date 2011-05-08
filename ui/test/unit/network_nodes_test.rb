
require File.dirname(__FILE__) + '/../test_helper'

require 'network_nodes'

#class ClusterService <ActiveRecord::Base
  #belongs_to :service
  #belongs_to :cluster
#end
#class ClusterNode <ActiveRecord::Base
  ## has_many :nodes
  #belongs_to :node
  #belongs_to :cluster
#end
  
class ClusterConfigurationTest < NetworkNodeTest
#  fixtures  :datacenters, :locations, :node_type, :cnu_machine_models, :distributions, :os_versions, :nodes, :clusters, :cluster_nodes, :cluster_services, :services

  def test_net_service
    #[ha_ip_address , port , proto, localport, "vlan#{vlan}" ].map {|e| e.to_s.strip() }
  end 
  def test_localport
      make_active_cluster
      #puts ClusterConfiguration.find(:all).inspect
      cc = ClusterConfiguration.find(:first, :conditions => ["local_port is null"]) 
      assert_not_nil cc
      assert_equal cc.port, cc.localport
      cc = ClusterConfiguration.find(:first, :conditions => ["local_port is not null"]) 
      assert_not_nil cc
      assert_equal cc.local_port, cc.localport
  end
end

class NodeTest < NetworkNodeTest
#  has_and_belongs_to_many  :nics, :join_table => 'node_nics'
#  belongs_to :node_type
##  belongs_to :cluster_nodes
#  has_and_belongs_to_many :sans, :join_table => 'san_nodes' 
#  belongs_to :os_version
#  belongs_to :location
#  has_many :cluster_configurations
  def test_create
     n = Node.make(:virtual )
    assert_not_nil n
  end

  # we don't use the make_active_cluster method because that in turn causes mgmt_ip_address_must_be_unique
  # validation to fire, which we want to test at a finer-grained level here...
  
  def test_mgmt_ip_address_must_be_unique_taken_by_other_node
    assert false, "Rewrite test now that mgmt ip address is a record id"
    node = Node.make :virtual
    dc = node.datacenter
    other_node = Node.make :virtual, :datacenter => dc
    cluster = Cluster.make(:cluster_name => "mgmt_#{dc.name}",:vlan => 4000, :ip_range => "10.0.0.0/8")
    ip = cluster.next_ip
    # can't use .make because ClusterNode table has no id
    ClusterNode.create(:node_id => other_node.id, :cluster_id => cluster.id, :ip_address => ip)

    assert node.valid?
    node.mgmt_ip_address = ip
    assert ! node.valid?
  end
  def test_mgmt_ip_address_must_be_unique_two_nodes_same_mgmt_ip
    assert false, "Rewrite test now that mgmt ip address is a record id"
    node = Node.make :virtual
    dc = node.datacenter
    other_node = Node.make :virtual, :datacenter => dc
    cluster = Cluster.make(:cluster_name => "mgmt_#{dc.name}",:vlan => 4000, :ip_range => "10.0.0.0/8")
    ip = cluster.next_ip
    other_node.mgmt_ip_address =ip 
    other_node.save

    assert node.valid?
    node.mgmt_ip_address = ip
    assert ! node.valid?
  end
  def test_mgmt_ip_address_must_be_unique_works
    cluster = make_active_cluster
    assert cluster.valid?
    cluster.nodes.each{ |n|
      assert n.valid?
    }
  end
  def test_remove
    assert_nothing_raised do
      lxm = LiveXenMap.make
      node = lxm.domu
      node.remove
      assert_raise ActiveRecord::RecordNotFound do
        Node.find node.id
      end
      assert_nil lxm.reload.client_id
    end
  end
end
#  def fqdn
#    "#{hostname}.#{location.datacenter.name}.example.com"
#  end
#  def fn_prefix
#    raise Exception.new('what the fuck') unless active?
##    "#{hostname}.#{location.datacenter.name}"
#  end
#  def uuid
#     return serial_no unless (serial_no.nil? or serial_no == '')
#     raise Exception.new('no uuid for you')
#  end
#  def nic_udev_rules
#      nics.map {|nic| nic.udev_rule }
#  end
#  def active?
#    (not node_type_id.nil?) && (node_type_id != 3) && (not location_id.nil?) 
#  end
#  def self.find_all_active(&block)
#      find(:all).select { |a| a.active? }
#  end
#
#  def self.find_all_physical(&block)
#      find(:all, :conditions => ['node_type_id = 1']).select { |a| a.active? && (not a.eth0.nil?) }
#  end
#  def mac_eth0
#    eth0.mac_address
#  end
#  def eth0
#    nics.find_by_port_name('eth0')
#  end

#########################################################################################

#  def new_node(email='',line1='3 High Street')
#    aop = Address.new() 
#  assert aop.save(false)
#	assert_not_nil aop
#	assert_equal 'London', aop.city
#	assert_not_nil c
#	assert_not_nil c.person
#	assert_not_nil c.person.company
#    c  
#  end
#
#  def test_create_denormalize_and_score
#	d = DenormalizedCustomer.create_denormalized(c)
#	assert_not_nil d
#	DenormalizedCustomer.create_fraud_scores(d)
#	fs = FraudScore.find(:first, :conditions =>["new_customer_id = ?", c.to_param])
#	assert_not_nil fs
#  end 
#  def test_fraud_score_with_several_customers
#
#	assert_equal 0.0, fs.email_score 
#	assert_equal 0.0, fs.company_score
#  end
#  def test_fill_data
#	assert_match /geo_zipE/, s
#	assert_no_match %r{  +}, s
#  end
#  def test_customer
#	cc = new_customer(10)
#  end
#
