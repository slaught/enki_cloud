require 'test_helper'

class DatabaseConfigsControllerTest < ActionController::TestCase

  def setup
    #controller.stub!(:authenticate).and_return(true)
    login_as(make_admin_user)
  end
    
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:database_configs)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_database_config

    assert_difference('DatabaseConfig.count') do
      post :create, :database_config => DatabaseConfig.plan
    end
    assert_redirected_to database_config_path(assigns(:database_config))
  end

  def test_should_show_database_config
    d = DatabaseConfig.make
    get :show, :id => d.id
    assert_response :success
  end

  def test_should_get_edit
    d = DatabaseConfig.make
    get :edit, :id => d.id
    assert_response :success
  end

  def test_should_update_database_config
    d = DatabaseConfig.make
    put :update, :id => d.id, :database_config => {:max_connections => 1001 }
    assert_redirected_to database_config_path(assigns(:database_config))
  end

  def test_should_destroy_database_config
    d = DatabaseConfig.make
    assert_difference('DatabaseConfig.count', -1) do
      delete :destroy, :id => d.id
    end

    assert_redirected_to database_configs_path
  end
end
