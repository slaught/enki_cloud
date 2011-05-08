require 'test_helper'

  
class DatabaseClusterAjaxTest < ActionController::IntegrationTest

  def test_remove_database_cluster
    # implicitly tests for adding as well as removing
    login_as make_dba_user
    cluster = make_active_cluster
    dbc = DatabaseCluster.make
    dbn = DatabaseName.make

    Capybara::visit "/database_clusters/show/#{dbc.id}"
    Capybara::select dbn.name, :from => 'database_name_database_name_id'
    Capybara::click_button 'Add'
    
    assert Capybara::has_content?(dbn.name)

    dbc = dbc.reload
    dbn = dbn.reload

    Capybara::visit "/database_clusters/show/#{dbc.id}"
    Capybara::click_button 'Remove'

    assert !(Capybara::has_link? dbn.to_label)
  end

end
