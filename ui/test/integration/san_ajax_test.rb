require 'test_helper'

  
class SanAjaxTest < ActionController::IntegrationTest

  def test_add_san_node
    login_as make_admin_user

    _san = San.make
    _san_nic = Nic.plan(:san)
    _node = Node.make(:virtual, :datacenter => _san.magic_datacenter)
    _node.add_san_nic(_san_nic[:mac_address], _san_nic[:port_name])

    Capybara::visit "/san/show/#{_san.id}"
    Capybara::select _node.to_label, :from => 'node_node_id'
    Capybara::click_button 'Add Node'

    assert Capybara::has_link? _node.to_label
  end

  def test_remove_san_node
    login_as make_admin_user

    _san = San.make
    _san_nic = Nic.plan(:san)
    _node = Node.make(:virtual, :datacenter => _san.magic_datacenter)
    _node.add_san_nic(_san_nic[:mac_address], _san_nic[:port_name])

    Capybara::visit "/san/show/#{_san.id}"
    Capybara::select _node.to_label, :from => 'node_node_id'
    Capybara::click_button 'Add Node'

    Capybara::visit "/san/show/#{_san.id}"
    Capybara::within(:css, "#remove_node_#{_node.id}") do
      Capybara::find("//input[@type='image'][1]").click
    end

    assert !(Capybara::has_link? _node.to_label)
  end

end
