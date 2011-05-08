require 'test_helper'

  
class NodeAjaxTest < ActionController::IntegrationTest

  def test_add_cluster
    login_as make_admin_user
    cluster = make_active_cluster
    node = make_proper_node :virtual 
    
    Capybara::visit "/node/show/#{node.id}"
    Capybara::select cluster.cluster_name, :from => 'cluster_cluster_id'
    Capybara::click_button 'Add To Cluster'

    assert Capybara::has_content? cluster.cluster_name
  end

end
