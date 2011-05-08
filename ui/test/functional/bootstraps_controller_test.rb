require 'test_helper'

class BootstrapsControllerTest < ActionController::TestCase
  def setup
    #controller.stub!(:authenticate).and_return(true)
    login_as(make_admin_user)
  end
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:bootstraps)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_bootstrap
    b = Bootstrap.plan 
    assert_difference('Bootstrap.count') do
      post :create, :bootstrap => b
    end
    assert_redirected_to bootstrap_path(assigns(:bootstrap))
  end

  def test_should_show_bootstrap
    @boot = Bootstrap.make
    get :show, :id => @boot.id
    assert_response :success
  end

  def test_should_get_edit
    @boot = Bootstrap.make
    get :edit, :id => @boot.id 
    assert_response :success
  end

  def test_should_update_bootstrap
    @boot = Bootstrap.make
    put :update, :id => @boot.id, :bootstrap => { :ip => '1.1.1.1' }
    assert_redirected_to bootstrap_path(@boot)
  end

  def test_should_destroy_bootstrap
    @boot = Bootstrap.make
    assert_difference('Bootstrap.count', -1) do
      delete :destroy, :id => @boot.id 
    end

    assert_redirected_to bootstraps_path
  end
end
