
require File.dirname(__FILE__) + '/../test_helper'
require 'network_nodes'

class NetworkSwitchportTest < NetworkNodeTest
#  fixtures  :datacenters, :locations, :node_type, :cnu_machine_models, :distributions, :os_versions, :nodes, :clusters, :cluster_nodes, :sans, :san_nodes, :xen_mappings, :serial_consoles, :pdus, :network_switch_ports

  def setup
    @sw = Node.active.find_by_node_type_id(14)
    assert_not_nil @sw
    @other_dc = Node.find_by_datacenter_id(1)
    @same_dc = Node.find_by_datacenter_id(@sw.datacenter_id)

    assert_not_nil @other_dc
    assert_not_nil @same_dc
  end
  def test_validations 
    r = NetworkSwitchPort.plug(@sw, @same_dc, 'a06')
    assert_valid  r
    r = NetworkSwitchPort.plug(@sw, @other_dc, 'a6')
    assert  ! r.valid?
    assert r.errors.invalid?(:switch_id)
  
    r = NetworkSwitchPort.plug(@sw, @same_dc, 'v99')
    assert ! r.valid?
    assert r.errors.invalid?(:port)
#=> #<ActiveRecord::Errors:0xb6e5d204 @base=#<NetworkSwitchPort id: nil, node_id: 91, switch_id: 147, port: "V6">, @errors={"port"=>["Wrong Port for HP Switches modules [A-H][0-9][0-9]"], "switch_id"=>["is not in the same datacenter as node"]}>
    r = NetworkSwitchPort.plug(@sw, @sw, 'a1')
    assert ! r.valid?
    assert r.errors.invalid?(:node_id) 
# => #<ActiveRecord::Errors:0xb6e67bc8 @base=#<NetworkSwitchPort id: nil, node_id: 147, switch_id: 147, port: "A06">, @errors={"node_id"=>["can't be plugged into self"]}>

#    assert_not_nil c
#    assert c.nodes == c.cluster_nodes.map { |cl| cl.node  }
#    assert_match %r{^#{@c.description}}, @c.title 
#    assert_equal @c.ha_ip_addresses, @c.ha_ip_address
#    assert_not_equal 0, Cluster.find_all_active.length 
#    assert_match %r[^ldirectord_\w+.cfg$], @c.ldirectord_cfg_filename 
  end
end
