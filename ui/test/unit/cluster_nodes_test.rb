
require File.dirname(__FILE__) + '/../test_helper'
require 'network_nodes'

class ClusterNodesTest < NetworkNodeTest
  # fixtures  :datacenters, :locations, :node_type, :cnu_machine_models, :distributions, :os_versions, :nodes, :clusters, :cluster_nodes

  def setup
  end
  def test_create
    dc = Datacenter.find_by_name('obr') 
    cluster = Cluster.make(:cluster_name => "mgmt_#{dc.name}",:vlan => 4000)
    assert_not_nil Cluster.find_mgmt_cluster_by_location(dc.name)
    node = Node.make(:virtual)
    cluster.add_node(node)
#    assert_difference 'Node.count' do
#      post :create, :node => @node
#    end
    @c = ClusterNode.find(:first) 
    assert_not_nil @c
    cc = Cluster.find(@c.cluster_id)
    assert_not_nil cc
  end
end
