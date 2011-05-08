
require 'test_helper'

class ClusterControllerTest < ActionController::TestCase

  def setup
    login_as(make_eng_user)
  end

  def test_should_get_index
    get :index
    assert_response :redirect
    assert_redirected_to( :controller => "cluster", :action => "list" )
    get :list 
    assert_response :success
    
    assert_not_nil assigns(:clusters)
    assert_template 'cluster/list'
  end
  def test_should_get_list_tex
    get :list , :format => "tex"
    assert_response :success
    assert_not_nil assigns(:clusters)
    assert_template 'cluster/list'
  end

  def test_should_show
    c = Cluster.make
    get :show, :id => c.id
    assert_response :success
    assert_not_nil assigns(:cluster)
    assert_template 'cluster/show'
    get :show, :id => c.id, :format => "xml"
    assert_response :success
    assert_not_nil assigns(:cluster)
  end
  def test_should_get_new
    get :new
    assert_response :success
    c = Cluster.make()
    assert_not_nil c
  end
  def test_should_edit
    o = Cluster.make
    get :edit, :id => o.id
    assert_response :success
    assert_not_nil assigns(:cluster)
  end
  def test_should_update
    c = Cluster.make()
    assert_not_nil c
    desc = 'XXXtestXXX'
    post :update, :id => c.id, :cluster => { :description => desc }
    assert_response :redirect
    assert_redirected_to( :controller => "cluster", :action => "show", :id => c.cluster_id)
  end
  def test_should_create
    c = Cluster.plan 
    assert_difference('Cluster.count') do
      post :create, :cluster  => c
    end
    assert_redirect( :controller => "cluster", :action => 'show' )
    assert_nil flash[:warning] 
    assert_no_match /^Error /, flash[:warning] 
    assert_no_match /^Missing Data:/, flash[:warning] 
  end
  def test_doesnt_pass_all_to_create 
    assert_no_difference('Cluster.count', 'Posting of invalid data') do
      post :create, :cluster => { } 
    end
  end
  def test_should_fail_to_create
#    c = Cluster.make()
#    assert_not_nil c
#    assert_no_difference('Cluster.count') do
#      assert_raise ActiveRecord::StatementInvalid do
#        post :create, :cluster  => c
#      end
#    end
  end

# TODO: add test to try and delete active cluster
#    unless c.active? and c.cluster_services.empty? and c.cluster_nodes.empty?
#        c.destroy
#        flash[:warning] = "Error deleting cluster"
#      flash[:warning] = "Can not delete ACTIVE cluster"
  def test_should_destroy
    c = Cluster.make
    assert_difference('Cluster.count', -1) do
      delete :destroy, :id => c.id 
    end
    assert_redirected_to( :controller => "cluster", :action => "list")
    assert_equal "Cluster Deleted!", flash[:notice]  
    assert_nil flash[:warning] 
  end
#  def test_doesnt_pass_all_to_create_too
#    post :create, :osversion => { } 
#    # todo, check flash
#    # flash[:warning] = "Missing Data: #{e.to_s}"
#    assert_response :success
#    assert_template 'software/new' 
#    assert_not_nil flash[:warning], "no flash message" 
#  end
###################
#  def status
#    @clusters = Cluster.find_all_active 
#    @active_colos = Datacenter.find_all_by_active(true);
#    @other_colos = Datacenter.find_all_by_active(false);
#    @load_balancers = @active_colos.map{|colo| Node.find_all_load_balancers(colo) }.flatten
#    render :layout => false
#    end
  def test_add_service
    c = Cluster.make
    s = Service.make
    assert_difference('ClusterService.count') do 
      xhr :post, :add_service,:id => c.id,  :service => { :service_id => s.id }
      assert_response :success
    end
  end
  def test_remove_service
    c = Cluster.make
    s = Service.make
    c.services << s
    assert_difference('ClusterService.count', -1) do 
      xhr :post, :remove_service, :id => c.id, :service => s.service_id
      assert_response :success
    end
  end
  def test_add_node 
    c = Cluster.make
    n = Node.make(:virtual)
    assert_difference('ClusterNode.count') do 
      xhr :post, :add_node, :id => c.id,  :node => { :node_id => n.id }
      assert_response :success
    end
  end
  def test_remove_node 
    c = Cluster.make
    n = Node.make(:virtual)
    c.merge_node(n)
    assert_difference('ClusterNode.count', -1) do 
      xhr :post, :remove_node, :id => c.id,  :node => n.id 
      assert_response :success
    end
  end
  def test_dba_cant_add_non_postgres_services
    login_as _make_user_with_role('dba', 'dbadmin')
    c = make_active_cluster
    s = Service.make(:local_port => nil)
    assert_no_difference('c.services.count') do
      xhr :post, :add_service, :id => c.id, :service => {:service_id => s.id}
    end
  end
  def test_dba_cant_remove_non_postgres_services
    login_as _make_user_with_role('dba', 'dbadmin')
    c = make_active_cluster
    s = c.services.detect{|s| s.ha_protocol != 'postgresql'}
    assert_no_difference('c.services.count') do
      xhr :post, :remove_service, :id => c.id, :service => s.service_id
    end
  end
end
