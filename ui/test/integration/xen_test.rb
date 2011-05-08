require 'test_helper'

  
class XenTest < ActionController::IntegrationTest

  def test_no_permissions_cant_see_delete_and_add
    rampart = Rampart.make
    RampartService.make :rampart => rampart
    rs = RampartService.make :rampart => rampart
    Capybara::visit "/rampart/show/#{rampart.id}"
    assert Capybara::page.has_content? rs.description
    assert Capybara::page.has_no_content?('Add Rampart Service')
    assert Capybara::page.has_no_content?('Delete')
  end  

end
