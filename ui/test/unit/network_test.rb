require 'test_helper'

class NetworkTest < ActiveSupport::TestCase
  # Replace this with your real tests.
#  def test_truth
#    assert true
#  end
  def test_create
    assert_not_nil Network.make
  end
  def test_ip_create
    assert_not_nil IpAddress.make
  end
  def test_ip_string
    # x = IpAddress.make(:ip_address => "10.10.10.10/24", :network => nil)
    x = IpAddress.make
    assert_not_nil x
    assert x.ip_address.length > 0
    assert_equal x.ip_address, x.to_s
    assert_equal x.to_s, x.ip 
  end
  def test_network_gw
    x = Network.make(:ip_range => "10.10.10.0/24")
    assert_not_nil x
    assert_equal "10.10.10.1", x.network_gateway
  end
#  def gateway
#    return @gw_cache unless @gw_cache.nil?
#    if network_gateway.nil?
#      @gw_cache = ip_query(%Q[SELECT host(network(cast('#{ip_range}' as cidr))+1) as ip_address ]) 
#    else
#      @gw_cache = ip(network_gateway)
#    end
#  end
  def test_network_gw
    x = Network.make(:ip_range => "10.10.10.0/24")
    assert_not_nil x
    assert_nil x.network_gateway
    assert_equal "10.10.10.1", x.gateway
  end

  def test_nettype
    assert_not_nil NetworkType.routable_network
    assert_not_nil NetworkType.campus_network
    assert_not_nil  NetworkType.private_network
    assert_not_nil  NetworkType.cluster_network
    assert_not_nil   NetworkType.public_network
  end
  def test_network_nettype
    x = Network.make
    assert x.vlan >= 1 && x.vlan <= 4096
    assert_not_nil x.ip_range 
    assert_match /#{x.vlan}/, x.to_label
    assert_match /#{x.ip_range}/, x.to_label
# #  validate , check ( network_gateway is null or network_gateway << ip_range )
  end
  def test_network_private_next_ip
    x = Network.make
    assert_not_nil x
    assert_nil x.next_ip()
  end
  def test_network_non_private_next_ip
    x = Network.make(:public)
    assert_not_nil x.next_ip()
  end
  def test_network_netmask
    x = Network.make
    assert_not_nil x.netmask 
    assert "255.255.255.0", x.netmask
  end
  def test_add_ip
    n = Network.make :ip_range => '10.8.10.0/24'
    assert_difference('IpAddress.count') do
      ip = n.add_ip '10.8.10.100'
      assert ip.ip_address == '10.8.10.100/24'
    end
    assert_no_difference('IpAddress.count') do
      assert_raise Exception do
        n.add_ip '1.2.3.4'
      end
    end
  end
end
