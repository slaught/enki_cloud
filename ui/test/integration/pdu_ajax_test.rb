require 'test_helper'

  
class PduAjaxTest < ActionController::IntegrationTest

  def test_list_unplug_pdu
    login_as make_admin_user

    p = Pdu.make
    node = p.node
    Capybara::visit "/pdu/list"

    Capybara::within(:css, "#remove_pdu_#{p.id}") do
      Capybara::find("//input[@type='image'][1]").click
    end

    assert Capybara::has_no_link? node.to_label
  end

  def test_show_unplug_pdu
    login_as make_admin_user

    p = Pdu.make
    n = p.node

    Capybara::visit "/pdu/show/#{p.pdu.id}"
    Capybara::save_and_open_page
    Capybara::within(:css, "#remove_pdu_#{p.id}") do
      Capybara::find("//input[@type='image'][1]").click
    end

    assert Capybara::has_no_link? n.to_label
  end

end
