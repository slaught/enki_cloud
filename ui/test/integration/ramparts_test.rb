require 'test_helper'

  
class RampartsTest < ActionController::IntegrationTest

  def test_add_template_service
    login_as make_admin_user
    rampart = Rampart.make
    Capybara::visit "/rampart/show/#{rampart.id}"
    assert_difference('rampart.rampart_services.count') do
      Capybara::within_fieldset('Add Rampart Service'){ Capybara::click_button 'Add' }
    end
    service = rampart.rampart_services.first
    assert Capybara::page.has_content? "#{service.description}"
    assert Capybara::page.has_content? "#{service.network}"
    assert Capybara::page.has_content? "#{service.protocol}"
    assert Capybara::page.has_content? "#{service.direction}"
  end

  def test_custom_form_hidden
    login_as make_admin_user
    rampart = Rampart.make
    Capybara::visit "/rampart/show/#{rampart.id}"
    assert ! Capybara::page.has_xpath?("//form[@id='custom_service_form']")
  end

  def test_no_permissions_cant_see_delete_and_add
    rampart = Rampart.make
    RampartService.make :rampart => rampart
    rs = RampartService.make :rampart => rampart
    Capybara::visit "/rampart/show/#{rampart.id}"
    assert Capybara::has_content? rs.description
    assert Capybara::page.has_no_content?('Add Rampart Service')
    assert Capybara::page.has_no_content?('Delete')
  end

  def test_create_delete
    node = Node.make :virtual
    login_as make_admin_user
    Capybara::visit "/rampart/new"
    Capybara::select node.to_label, :from => 'rampart_node_id'
    Capybara::check 'Has public ip'
    Capybara::check 'Has service ip'
    assert_difference('Rampart.count') do
      Capybara::click_button 'Create'
      assert Capybara::page.has_content? "Rampart was successfully created."
    end
    rampart = Rampart.find_by_node_id(node.id)
    assert_not_nil rampart

    Capybara::visit '/rampart/list'
    assert Capybara::locate("//a[.='#{node.to_label}']/../..").find("//td[.='#{rampart.public_ip_address}']")
    assert Capybara::locate("//a[.='#{node.to_label}']/../..").find("//td[.='#{rampart.locale_ip_address}']")
    assert_difference('Rampart.count', -1) do
      Capybara::locate("//a[.='#{node.to_label}']/../..").find("//a[@title='Destroy']").click
      assert Capybara::page.has_content? "Rampart was DESTROYED."
      assert ! Capybara::page.has_xpath?("//a[.='#{node.to_label}']")
    end
  end
end
