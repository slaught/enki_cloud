
require File.dirname(__FILE__) + '/../test_helper'
require 'network_nodes'

class ServiceTest < NetworkNodeTest
#  fixtures  :protocols, :services

  include CNU::Conversion
  def setup
    mark = ip2dec('127.0.7.1')
    # Service.make
    Service.make(:name => 'jabber',:url=>'xmpp://jabber.example.com')
    @s = Service.find(:first) 
    assert_not_nil @s
  end
  def test_find
    c = Service.find_by_name('jabber')
    assert_not_nil c
  end
  def test_find_ha
      s1 = Service.find_ha_ip_services('10')
      s2 = Service.find_ha_ip_services('10.11')
      assert_equal s1.length, s2.length
  end
  def cnt_format(n)
      require 'set'
      n.times { Service.make }
      svc = Service.find(:all, :conditions =>["url is not null"], :limit => n)
      assert_equal 1 * n, svc.length, "Not enough data"
      fmt = Service.format_services(svc)
      assert_equal 1 * n,  fmt.length, "Wrong count of fmt"
      assert_equal 6, fmt.first.length
      len = fmt.map {|f| f.length }
      assert_equal 1, Set.new(len).length
      assert_equal 6, Set.new(len).to_a.first
  end
  def test_format
      fmt = Service.format_services([Service.find(:first)])
      assert_equal 1,  fmt.length
      assert_equal 6, fmt.first.length
      cnt_format(1)
      # cnt_format(3) # can't get thisto work
  end
  def test_ha_port_proto
    s = Service.find(:first)
    assert_equal s.service_port, s.ha_port
    assert_equal s.protocol.proto.strip, s.ha_proto
  end
  def test_uri
    s = Service.find_by_name('jabber') 
    assert_not_nil s.ha_hostname
    assert_match /jabber/, s.ha_hostname
    assert_not_nil s.ha_protocol
    assert ['http','https','xmpp'].member?(s.ha_protocol)
  end
  def test_ssl?
    Service.make(:url  => 'https://www.example.com')
    Service.make
    s = Service.find(:first, :conditions => ["url like 'https:%%'"])
    assert_not_nil s, "Can't find a https service"
    assert_not_nil s.ssl?
    assert s.ssl?
    s = Service.find(:first, :conditions => ["url like 'http:%%'"])
    assert_not_nil s.ssl?
    assert !s.ssl?
  end
  def test_localport
    Service.make(:local_port => nil)
    s = Service.find(:first, :conditions => ['local_port is null'])
    assert_not_nil s, "Can't find a loca_port is null service"
    assert_nil s.local_port
    assert_not_nil s.localport
    assert_equal s.service_port, s.localport
  
  end
  def test_listings_private
    Service.make(:ip_address => '10.10.10.1')
    r = Service.private_services
    assert_not_nil r
    assert r.length > 0, "No private services found"
    assert_equal 6, r.first.length
  end
  def test_listings
    Service.make(:ip_address => '209.60.186.24')
    r = Service.public_services
    assert_not_nil r
    assert r.length > 0, "No public services found"
    assert_equal 6, r.first.length
  end

  def test_check_url_format
    s = Service.make :check_url => '/ping'
    assert s.valid?
    s.check_url = 'http://example.com/ping'
    assert ! s.valid?
  end
end
