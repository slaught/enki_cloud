#:
#test_active(ClusterTest)
#2) Failure: #                test_cluster_nodes(ClusterTest)
# 3) Failure: #                                test_find(ClusterTest)
#
require File.dirname(__FILE__) + '/../test_helper'
require 'network_nodes'

class Cluster
  def test_vlan_fallback(x)
      vlan_fallback_ip(x)
  end
end
class ClusterTest < NetworkNodeTest
#  fixtures  :datacenters, :locations, :node_type, :cnu_machine_models, :distributions, :os_versions, :nodes, :clusters, :cluster_nodes
  include CNU::Conversion 

  def test_fwmark
    mark = ip2dec('127.0.7.1')
    @c = Cluster.make :fw_mark => ip2dec('127.0.7.1')
    assert_not_nil @c
    assert_equal @c.fw_mark, mark
    assert @c.save
  end
  def test_find
    Cluster.make(:vlan => 7) 
    c = Cluster.find_by_vlan(7)
    
    assert_not_nil c
  end
  def test_cluster
    @c = Cluster.make
    assert_equal @c.cluster_name, @c.name
  end
  def test_cluster_nodes
    #assert @c.nodes.length > 0 
    Cluster.make :cluster_name => 'test'
    c = Cluster.find_by_cluster_name('test')
    assert_not_nil c
    assert c.nodes == c.cluster_nodes.map { |cl| cl.node  }
  end
  def test_title 
    @c = Cluster.make
    assert_match %r{^#{@c.description}}, @c.title 
  end 
  def test_services
    # cluster_services
    # services
  end
  def test_ha_ip
    @c = Cluster.make
    assert_equal @c.ha_ip_addresses, @c.ha_ip_address
  end
  def test_active
    c = make_active_cluster
    assert_not_nil c
    assert c.fw_mark? , "No forward mark"
    assert (not  c.cluster_services.empty?)
    assert (not c.cluster_nodes.empty?)
    #fw_mark and (not self.cluster_services.empty?) and (not self.cluster_nodes.empty?)
    #assert_equal @c, Cluster.find(:first)
    assert c.active?
    
    assert_not_equal 0, Cluster.find_all_active.length 
  end
  def test_ldirectord
    @c = Cluster.make
    assert_match %r[^ldirectord_\w+.cfg$], @c.ldirectord_cfg_filename 
  end
  
  def test_vlan_fallback_ip
    c = Cluster.make
    x = c.test_vlan_fallback(9999)
    assert_equal String, x.class
    assert_equal "127.9999.0.1", x
  end
  def test_fw_mark_auto_update
    c = Cluster.make
    fwmark_old = c.fw_mark
    c.vlan = c.vlan + 1
    assert c.save
    assert c.reload.fw_mark != fwmark_old
  end
  def test_next_fw_mark
    vlan = Sham.vlan
    Cluster.make :vlan => vlan, :fw_mark => ip2dec("127.%d.255.255" % vlan)
    assert Cluster.next_forward_mark(vlan) == ip2dec("127.%d.0.1" % vlan)
  end
end
