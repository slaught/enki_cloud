require 'test_helper'

class RampartTest < ActiveSupport::TestCase
  def test_old_ips_destroyed_on_update
    public_ip = Rampart.public_network.next_ip
    locale_ip = Rampart.locale_network.next_ip
    @rampart = Rampart.make :has_public_ip => true, :public_ip_address => public_ip,
      :has_service_ip => true, :locale_ip_address => locale_ip
    @rampart.public_ip_address = Rampart.public_network.next_ip
    @rampart.locale_ip_address = Rampart.locale_network.next_ip
    @rampart.save
    assert_equal false, IpAddress.exists?(public_ip.attributes)
    assert_equal false, IpAddress.exists?(locale_ip.attributes)
  end
  def test_old_ips_destroyed_on_destroy
    public_ip = Rampart.public_network.next_ip
    locale_ip = Rampart.locale_network.next_ip
    @rampart = Rampart.make :has_public_ip => true, :public_ip_address_id => public_ip.id,
      :has_service_ip => true, :locale_ip_address_id => locale_ip.id
    @rampart.destroy
    assert_equal false, IpAddress.exists?(public_ip.attributes)
    assert_equal false, IpAddress.exists?(locale_ip.attributes)
  end
  def test_no_service_has_public
    public_ip = Rampart.public_network.next_ip
    @rampart = Rampart.make :has_public_ip => true, :public_ip_address => public_ip
    assert_not_nil @rampart 
  end
  def test_has_service_no_public
    locale_ip = Rampart.locale_network.next_ip
    @rampart = Rampart.make :has_service_ip => true, :locale_ip_address => locale_ip
    assert_not_nil @rampart 
  end
  def test_services_unique
    r = Rampart.make
    s1 = RampartService.make(:protocol => 'udp', :direction => 'in', :network => "10.10.10.0/24",
      :description => Sham.description)
    s2 = RampartService.make(:protocol => 'udp', :direction => 'in', :network => "10.10.10.0/24",
      :description => Sham.description)
    r.rampart_services << s1
    assert !(r.rampart_services << s2)
  end
end
