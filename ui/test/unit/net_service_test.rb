require 'test_helper'

class NetServiceTest < ActiveSupport::TestCase
#    assert_not_nil x
##    assert_nil x.network_gateway
#    assert_equal "10.10.10.1", x.gateway
#    assert_match /#{x.ip_range}/, x.to_label
#    assert_not_nil x.netmask 
#    assert "255.255.255.0", x.netmask
#    n = Network.make :ip_range => '192.168.10.0/24'
#    assert_difference('IpAddress.count') do
#      ip = n.add_ip '192.168.10.100'
#      assert ip.ip_address == '192.168.10.100/24'
#    end
#    assert_no_difference('IpAddress.count') do
#      assert_raise Exception do
#        n.add_ip '1.2.3.4'
#      end
#    end
  def test_net_services
      cluster = make_active_cluster
      svcs = cluster.services
      cluster.nodes.each {|n|
        assert_not_nil n.net_services
        svcs.each do |s|
          assert_match /#{s.ip_address}/, n.net_services
          assert_match /::#{s.ha_proto}:#{s.localport}:eth4000/, n.net_services
          assert_match /#{s.ip_address}:#{s.ha_port}:#{s.ha_proto}:#{s.localport}:#{n.net_type}\d+/, n.net_services
        end
        assert_match /icmp::eth\d+/, n.net_services
        assert_match /\s"::tcp:80:eth\d+"/, n.net_services
      }
  end
  def test_net_services_san
    n = make_san_node
    san_nics = n.san_nics
    assert_not_nil san_nics
    assert san_nics.length > 0
    san_nics.each do |nic|
      assert_match /::tcp:22:#{nic.port_name}/, n.net_services
    end
  end
  def test_net_services_load_balancer
    
  end
  def test_net_type
    v = Node.make(:virtual)
    assert_equal 'eth',v.net_type, "virutal node uses eth"
    p = Node.make(:physical)
    assert p.node_type.name != 'virtual' #is_physical?
    assert_equal 'vlan', p.net_type, "physical node uses vlan"
  end
  def test_mangle
    n = Node.make(:virtual)
    assert_equal '4000',n.mangle('555')
  end
  def net_services
#    svc = []
#    clusters.each do |cc| 
#      cc.services.each {|s|
#          svc << [s.ha_ip_address , s.ha_port ,
#            s.ha_proto, s.localport,
#           "#{net_type}#{cc.vlan}" # local interface
#          ]
#      }
#      svc << [nil, nil,'icmp', nil, 
#          "#{net_type}#{cc.vlan}" # local interface
#        ]
#    end
#    if is_server? then 
#       svc2 = []
#       svc.each { |s| 
#          svc2 << ["","",s[2],s[3], mangle(s[4])]
#          svc2 << ["","",s[2],s[3], s[4]]
#       }
#      #puts "DEBUG:#{hostname}: #{svc2.inspect}" if is_load_balancer? 
#      svc.concat(svc2)
#    end
#    # will be wrong for virutal with SANs
#    san = san_nics.map { |nic| [nil, nil, 'tcp', 22, nic.port_name] }
#    svc.concat(san)
    if node_type.is_loadbalancer?
       ha_svc = ClusterConfiguration.find_all_ha_net_services
       svc.concat(ha_svc)
       # For Testing only - Delete after Feb 28, 2009 or come up with
       # something better
       test_vlans = Cluster.find(:all, :conditions => ["vlan <= 102 and vlan > 8"]).map{|c| c.vlan }
       testing_svc = test_vlans.map{|vlan|
                            [nil,nil,'tcp',22, "vlan#{vlan}"]
                      }.uniq
       svc.concat(testing_svc)
       testing_svc = test_vlans.map{|vlan|
                            [nil,nil,'icmp',nil, "vlan#{vlan}"]
                      }.uniq
       svc.concat(testing_svc)
    end
    # Icmp for application vlans
    if node_type.is_virtual?
      icmp = nics.map { |nic| 
         [nil,nil,'icmp',nil, nic.port_name]  if nic.port_name =~ /eth\d+/ 
      }.compact
      svc.concat(icmp)
      nginx = nics.map { |nic| 
         [nil,nil,'tcp', 80, nic.port_name]  if nic.lan? and nic.port_name =~ /eth\d+/ 
      }.compact
      svc.concat(nginx)
    end
    if hostname == 'uu01' then
      svc << [nil,nil,'tcp',11301,'eth4000']
    end
    svc.map{|a| %Q(\t"#{a.join(':')}") }.sort.uniq.join("\n")
  end
#    Service.make(:name => 'jabber',:url=>'xmpp://jabber.example.com')
#Service.make(:url  => 'https://www.example.com')
#Service.make(:local_port => nil)
#Service.make(:ip_address => '10.10.10.1')
#Service.make(:ip_address => '192.0.2.24')
#
#Node.make(:virtual)
#dc = Datacenter.find(:first)
#cluster = Cluster.make(:cluster_name => "mgmt_#{dc.name}",:vlan => 4000)
#DatabaseConfig.make
#d = DatabaseName.make
#
#
#      cluster = make_active_cluster
#      node = 
#    Service.make(:name => 'jabber',:url=>'xmpp://jabber.example.com')
#Service.make(:url  => 'https://www.example.com')
#Service.make(:local_port => nil)
#Service.make(:ip_address => '10.10.10.1')
#Service.make(:ip_address => '192.0.2.24')
#
#Node.make(:virtual)
#dc = Datacenter.find(:first)
#cluster = Cluster.make(:cluster_name => "mgmt_#{dc.name}",:vlan => 4000)
#DatabaseConfig.make
#d = DatabaseName.make
#
###########################################################3
end
