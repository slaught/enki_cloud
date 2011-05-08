require 'test_helper'

class DatabaseNamesControllerTest < ActionController::TestCase

  def setup
    #controller.stub!(:authenticate).and_return(true)
    login_as(make_admin_user)
    DatabaseName.make
    DatabaseName.make
  end
    
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:database_names)
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_get_new
    get :new
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_create_database_name
    assert_difference('DatabaseName.count') do
      post :create, :database_name => DatabaseName.plan
    end
    #assert_redirected_to database_name_path(assigns(:database_name))
    assert_redirected_to database_names_path(assigns(:database_names))
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_show_database_name
    d = DatabaseName.make
    get :show, :id => d.id
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_get_edit
    d = DatabaseName.make
    get :edit, :id => d.id
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_update_database_name
    d = DatabaseName.make
    put :update, :id => d.id, :database_name => {:description => 'test description here'}
    assert_redirected_to database_name_path(assigns(:database_name))
    assert_no_match /TemplateError/, @response.body
  end

  def test_should_destroy_database_name
    d = DatabaseName.make
    assert_difference('DatabaseName.count', -1) do
      delete :destroy, :id => d.id
    end
    assert_redirected_to database_names_path
    assert_no_match /TemplateError/, @response.body
  end
end
