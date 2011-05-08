require 'test_helper'

class DatabaseClustersControllerTest < ActionController::TestCase
  tests DatabaseClustersController

  def setup
    #controller.stub!(:authenticate).and_return(true)
    login_as(make_admin_user)
    make_db_cluster
  end

  def test_should_get_config 
    dc = make_db_cluster(:version => '8.3')
    get :config , :id => dc.id
    assert_successful_render
    assert_not_nil assigns(:database_cluster)
  end
    
  def test_should_get_index
    make_db_cluster
    get :index
    assert_successful_render
    assert_not_nil assigns(:database_clusters)
  end

  def test_should_get_new
    get :new
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_create_database_cluster
    s = Service.make
    assert_not_nil s
    dbc = DatabaseConfig.make
    assert_not_nil dbc
    dc = DatabaseCluster.plan
    assert_not_nil dc
    dc.merge!({:service_id => s.id, :database_config_id => dbc.id})
    assert_equal s.id, dc[:service_id]
    assert_difference('DatabaseCluster.count') do
      post :create, :database_cluster => dc
    end
    assert_redirected_to database_cluster_path(assigns(:database_cluster))
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_show_database_cluster
    d = make_db_cluster 
    get :show, :id => d.id
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_get_edit
    d = make_db_cluster 
    get :edit, :id => d.id
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_update_database_cluster
    d = make_db_cluster 
    put :update, :id => d.id, :database_cluster => {:description => 'test description'}
    assert_nil flash[:warning]
    assert_nil flash[:error]
    assert_redirected_to database_cluster_path(assigns(:database_cluster))
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_destroy_database_cluster
    d = make_db_cluster 
    assert_difference('DatabaseCluster.count', -1) do
      delete :destroy, :id => d.id
    end

    assert_redirected_to database_clusters_path
    assert_no_match /TemplateError/, @response.body
  end

  def test_add_database
    c = make_db_cluster 
    n = DatabaseName.make
    assert_difference('DatabaseClusterDatabaseName.count') do 
      xhr :post, :add_database,:id => c.id,  :database_name => { :database_name_id=> n.id }
      assert_response :success
    end
  end
  def test_remove_database
    c = make_db_cluster 
    n = DatabaseName.make
    c.database_names << n
    assert_difference('DatabaseClusterDatabaseName.count',-1) do 
      xhr :post, :remove_database,:id => c.id, :database_name => n.id 
      assert_response :success
    end
  end
end
