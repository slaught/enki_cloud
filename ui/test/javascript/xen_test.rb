require 'javascript_test_helper'

  
class XenTest < JavascriptTest

  # FIXME
  def test_add_mapping
    login_as make_admin_user
    xm = XenMapping.make
    host = Node.find(xm.host_id)
    unmapped = Node.make :virtual, :datacenter => host.datacenter

    Capybara::visit "/xen/compare"
    Capybara::within("//h3[@id='#{host.datacenter.name}_mappings_header']") do
      Capybara::click_link '+'
    end rescue raise Exception.new "FIXME: test is outdated since the xen page rewrite. Redo or remove..."
    Capybara::within("//form[@id='#{host.to_label}_toggle_add_mapping_form_button']") do
      Capybara::click_button 'Map a guest to this host'
    end
    Capybara::find_button('Add Mapping').click
    assert Capybara::has_content?("#{unmapped.to_label}")
  end

end
