
require 'test_helper'

class ServiceControllerTest < ActionController::TestCase

  def setup
    login_as(make_admin_user)
    @service = Service.make
  end

  def test_should_get_index
    get :index
    assert_response :redirect
    assert_redirected_to( :controller => "service", :action => "list" )
    get :list
    assert_response :success
    assert_not_nil assigns(:services)
    assert_template 'service/list'
  end
  def test_index_then_edit
    get :list
    assert_response :success
    get :edit, :id => @service.id
    assert_response :success 
  end
  def test_should_show
    s = Service.make
    get :show, :id => s.id
    assert_response :success
    assert_not_nil assigns(:service)
    assert_template 'service/show'
    assert_tag :tag => 'em', :child => /#{s.description}/
  end
  def test_should_get_new
    get :new
    assert_response :success
    a = Service.make()
    assert_not_nil a
  end
  def test_should_edit
    o = Service.make
    get :edit, :id => o.id
    assert_response :success
    assert_not_nil assigns(:service)
  end
  def test_should_create
    s = Service.plan
    assert_difference 'Service.count' do
      post :create, :service => s
    end
    assert_response :redirect 
    assert_redirect(:controller => 'service', :action => "show")
    assert_nil flash[:warning]
    assert_match /create/, flash[:notice]
  end
  def test_create_with_duplicate_local_port
    s1 = Service.make
    s = Service.plan(:local_port => s1.local_port)
    assert_no_difference 'Service.count' do
      post :create, :service => s
    end
    assert_match /Local port.+duplicate/, @response.body
  end

  def test_update
    s = Service.make
    desc = 'XXXtestXXX'
    get :edit, :id => s.id
    assert_response :success
    post :update, {:id=> s.service_id, :service => {:description => desc } }
    assert_response :redirect
    assert_redirected_to :controller => "service", :action => "show", :id => s.service_id
    assert_match /Service was successfully updated/ , flash[:notice]
  end
  def test_update_with_duplicate_local_port
    s = Service.make
    s1 = Service.make
    assert_no_difference 'Service.count' do
      post :update, {:id => s.id, :service => {:local_port => s1.local_port}}
    end
    assert_match /Local port.+duplicate/, @response.body
  end

  def test_showname
    s = Service.make(:name => 'single_unused_name')
    get :show_name, :id => s.name
    assert_response :redirect
    assert_redirected_to :controller => "service", :action => "show", :id => s.service_id
    #assert_response :success 
    #assert_match /#{s.name}/, @response.body
    #assert_not_nil assigns(:service)
    #assert_template 'service/show'
  end
  def test_should_showname_many
    s = Service.make
    s2 = Service.make(:name => s.name, :ip_address => s.ip_address )
    get :show_name, :id => s.name
    assert_response :success 
    assert_match /#{s.name}/, @response.body
    assert_nil assigns(:service)
    assert_not_nil assigns(:services)
    assert_tag :tag => 'table', :child => /#{s.name}/
    assert_template 'service/list'
  end
  def test_listjson
    get :listjson
    assert_response :success 
    s = Service.make
    get :listjson, :q => s.name
    assert_response :success 
    assert_not_nil assigns(:services)
#    render :json => { :results => data }.to_json 
  end
  def test_add_dependency_form
    s = Service.make
    get :add_dependency_form, :id => s.id  
    assert_response :success 
    assert_not_nil assigns(:service)
    assert_template 'service/_adddependency'
  end
  def test_add_dependency
    s = Service.make
    child = Service.make
    
    assert_difference 'ServiceDependency.count' do
      post :add_dependency, :service => {:id => s.id},:dependency =>{:id => child.id}
    end
    assert_response :redirect
    assert_redirected_to :controller => "service", :action => "show", :id => s.service_id
    assert_not_nil assigns(:service)
    assert_match  /Service Dependency was successfully added/, flash[:notice]
#     flash[:warning] = "There was a problem adding your dependency!"
  end

  def test_remove_dependency
    s = Service.make
    child = Service.make
    sd = ServiceDependency.create( :parent => s, :child => child)
    assert_difference('ServiceDependency.count', -1 ) do
      post :del_dependency, :id => sd.id 
    end
    assert_response :redirect
    assert_redirected_to :controller => "service", :action => "show", :id => s.service_id
    assert_not_nil assigns(:service)
    assert_match  /The dependency was successfully removed! Yay!/ , flash[:notice]
  end
end
