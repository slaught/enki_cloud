require 'javascript_test_helper'

  
class RampartsTest < JavascriptTest

  def test_add_custom
    login_as make_admin_user
    rampart = Rampart.make
    Capybara::visit "/rampart/show/#{rampart.id}"
    Capybara::select 'Custom...', :from => 'rampart_service_template_id'
    description = Sham.description
    Capybara::fill_in 'rampart_service_description', :with => description
    Capybara::click_button 'Add'
    Capybara::wait_until{ Capybara::page.has_content? "#{description}" }
    rampart = rampart.reload
    service = rampart.rampart_services.first
    assert Capybara::has_content? "#{service.network}"
    assert Capybara::has_content? "#{service.protocol}"
    assert Capybara::has_content? "#{service.direction}"
  end

  def test_delete_service
    login_as make_admin_user
    rampart = Rampart.make
    service = RampartService.make :rampart => rampart
    Capybara::visit "/rampart/show/#{rampart.id}"
    Capybara::click_link 'Delete'
    ajax_safe{ assert Capybara::has_no_xpath?("//td[.='#{service.description}']") }
    assert Capybara::has_no_xpath?("//td[.='#{service.network}']")
    assert Capybara::has_no_xpath?("//td[.='#{service.protocol}']")
    assert Capybara::has_no_xpath? "//td[.='#{service.direction}']"
  end

  def test_get_ips
    login_as make_rampart_admin_user
    rampart = Rampart.make
    Capybara::visit "/rampart/edit/#{rampart.id}"
    Capybara::check 'Has public ip'
    Capybara::click 'rampart_public_ip_address_get'
    ip = IpAddress.find_by_ip_address(Capybara::find_field("Public ip address").value+'/'+cidr_mask(Rampart.public_network.ip_range))
    assert ip.network == Rampart.public_network
    rampart = rampart.reload
    assert rampart.public_ip_address == ip

    Capybara::check 'Has service ip'
    Capybara::click 'rampart_locale_ip_address_get'
    ip = IpAddress.find_by_ip_address(Capybara::find_field("Locale ip address").value+'/'+cidr_mask(Rampart.locale_network.ip_range))
    assert ip.network == Rampart.locale_network
    rampart = rampart.reload
    assert rampart.locale_ip_address == ip
  end

  def test_update
    other_node = Node.make :virtual
    @rampart = Rampart.make :has_public_ip => true, :public_ip_address => Rampart.public_network.next_ip,
      :has_service_ip => true, :locale_ip_address => Rampart.locale_network.next_ip, :home_network => 'qa'
    login_as make_admin_user
    Capybara::visit "/rampart/edit/#{@rampart.id}"
    assert has_selected_option?(@rampart.node.to_label)
    assert has_selected_option?('QA')
    assert Capybara::has_content?(@rampart.public_ip_address.to_s)
    assert Capybara::has_content?(@rampart.locale_ip_address.to_s)

    Capybara::uncheck('Has public ip')
    assert Capybara::has_no_content? @rampart.public_ip_address.to_s
    Capybara::uncheck('Has service ip')
    assert Capybara::has_no_content? @rampart.locale_ip_address.to_s
    Capybara::select 'Dev', :from => 'Home network'
    Capybara::select other_node.to_label, :from => 'rampart_node_id'
    Capybara::click_button 'Update'

    assert Capybara::has_content? 'Rampart was successfully updated.'
    assert_equal(nil,
      Capybara::locate("//a[.='#{other_node.to_label}']/../..").find("//td[.='#{@rampart.public_ip_address}']"))
    assert_equal(nil,
      Capybara::locate("//a[.='#{other_node.to_label}']/../..").find("//td[.='#{@rampart.locale_ip_address}']"))
    assert Capybara::locate("//a[.='#{other_node.to_label}']/../..").find("//td[.='dev']")
  end

end
