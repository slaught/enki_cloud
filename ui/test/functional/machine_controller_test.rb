
require 'test_helper'

class MachineControllerTest < ActionController::TestCase
  def setup
    login_as(make_admin_user)
    @machine = CnuMachineModel.make 
  end

  def test_should_get_index
    get :list 
    assert_response :success
    assert_not_nil assigns(:machines)
  end
  def test_should_create
    b = CnuMachineModel.plan
    assert_difference('CnuMachineModel.count') do
      post :create, :machine => b
    end
    assert_response :redirect
    assert_redirect( :controller => 'machine', :action => "show"  )
  end
#  def test_should_destroy
#    @boot = CnuMachineModel.make
#    assert_difference('CnuMachineModel.count', -1) do
#      delete :destroy, :id => @boot.id 
#    end
#    assert_redirected_to :action => 'list' 
#  end
  def test_should_get_new
    get :new
    assert_response :success
    assert_template 'machine/new'
  end
  def test_should_edit
    get :edit, :id => @machine.id
    assert_response :success 
    assert_template 'machine/edit'
  end
  def test_should_update
    cpus = 5
    post :update, :id=> @machine.model_id, :machine => {:cpu_cores => cpus }  
    assert_response :redirect
    assert_redirected_to( :controller => "machine", :action => "show", :id => @machine.model_id )
  end
  def test_should_show
    get :show, :id => @machine.model_id  
    assert_response :success 
    assert_template 'machine/show'
    assert_tag :tag => 'h1', :child => /#{@machine.model_no}/
  end

end
