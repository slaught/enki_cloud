require 'test_helper'
 
class ClusterAjaxTest < ActionController::IntegrationTest

  def test_remove_node
    login_as make_admin_user

    c = make_active_cluster
    n = c.nodes.first

    Capybara::visit "/cluster/show/#{c.id}"

    Capybara::within(:css, "#remove_node_#{n.node_id}") do
      click_button_titled('Remove')
    end

    assert !(Capybara::has_link? n.to_label)
  end

  def test_add_node
    login_as make_admin_user

    c = make_active_cluster
    n = Node.make(:virtual)

    Capybara::visit "/cluster/show/#{c.cluster_id}"
    Capybara::select n.to_label, :from => 'node_node_id'
    Capybara::click_button 'Add Node'

    assert Capybara::has_link? n.to_label
  end

  def test_remove_service
    login_as make_admin_user

    c = make_active_cluster
    s = c.services.first

    Capybara::visit "/cluster/show/#{c.cluster_id}"
    Capybara::within(:css, "#remove_service_#{s.service_id}") do
      Capybara::click_button("Remove")
    end

    assert !(Capybara::has_link? "/service/show/#{s.service_id}")
  end

  def test_add_service
    login_as make_admin_user

    c = make_active_cluster
    s = Service.make
    
    Capybara::visit "/cluster/show/#{c.cluster_id}"
    
    Capybara::select s.to_label, :from => 'service_service_id'
    Capybara::click_button 'Add Service'
    
    assert Capybara::has_link? s.name

  end

end
