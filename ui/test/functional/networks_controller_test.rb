require 'test_helper'

class NetworksControllerTest < ActionController::TestCase

  def setup
    login_as(make_admin_user)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_successful_render
    assert_not_nil assigns(:networks)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create network" do
    assert_difference('Network.count') do
      post :create, :network => Network.plan
    end
    assert_redirected_to network_path(assigns(:network))
  end

  test "should show network" do
    x = Network.make
    get :show, :id => x.to_param
    assert_response :success
  end

  test "should get edit" do
    x = Network.make
    get :edit, :id => x.to_param
    assert_response :success
  end

  test "should update network" do
    x = Network.make 
    put :update, :id => x.to_param, :network => { }
    assert_redirected_to network_path(assigns(:network))
  end

  test "should destroy network" do
    x = Network.make
    # x = Network.make
    assert_difference('Network.count', -1) do
      delete :destroy, :id => x.to_param
      assert_redirected_to networks_path
      assert_equal Hash.new, @response.flash
    end
  end
end
