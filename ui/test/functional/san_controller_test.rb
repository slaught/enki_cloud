
require 'test_helper'

#  def should_get_index(usermsg)
#    get :index
#    assert_response :success
#    assert_template 'welcome/index'
#    assert_equal 'layouts/welcome', @response.layout, "Wrong layout"
#    assert_select 'div#user_bar_frontpage ul li#user-bar-greeting' do |e|
#      assert_match usermsg, e.to_s 
#    end
#    assert_match usermsg,@response.body
#  end

class SanControllerTest < ActionController::TestCase

  def setup
    login_as(make_admin_user)
  end

#  def test_should_allow_signup
#    assert_difference 'User.count' do
#      create_user
#      assert_response :redirect
#    end
#  def test_should_require_login_on_signup
#    assert_no_difference 'User.count' do
#      create_user(:login => nil)
#      assert_response :success
#    end
#  def test_should_require_email_on_signup
#    assert_no_difference 'User.count' do
#      create_user(:email => nil)
#      assert assigns(:user).errors.on(:email)
#      assert_response :success
#    end
# *  was the web request successful?
# * was the user redirected to the right page?
# * was the user successfully authenticated?
# * was the correct object stored in the response template?
# * was the appropriate message displayed to the user in the view
#
#  def create_san(options = {})
#      post_with users('admin'), :create, :san=> { :san_name=> 'CNU-TEST-SAN', :description => 'xxx',
#        :vlan => 5, :ip_range =>'1.1.0.0/24' }.merge(options)
#  end
  def test_create_san
    s = San.plan 
    assert_difference 'San.count' do
      post :create, :san => s
    end
    assert_response :redirect
    assert_redirect :action => "show" , :controller => 'san'
  end
  def test_should_show_index
    get :list 
    assert_response :success 
  end
  def test_should_edit
    s = San.make 
    get :edit, :id => s.san_id
    assert_response :success 
  end
  def test_should_update
    @san = San.make 
    desc = 'XXXtestXXX'
    post :update, :id => @san.id, :san => { :description => desc }
    assert_response :redirect
    assert_redirected_to :controller => "san", :action => "show", :id => @san.san_id
  end
  def test_show
    @san = San.make 
    get :show, :id => @san.san_id
    assert_response :success 
    assert_template 'show'
    assert_tag :tag => 'em', :child => /#{@san.description}/
  end

  def test_try_add_node
    @san = San.make 
    @node = make_san_node
    assert_difference('SanNode.count', 2, "Adding two san connections") do
      xhr :post, :add_node, { :id => @san.id,:node => {:node_id => @node.id}} 
      assert_response :success
      assert_template '_node_list'
      assert_no_match /Error/, flash[:notice]
      assert_no_match /Error/, flash[:warning]
      assert_nil flash[:warning]
    end
    assert_equal 2, @san.nodes.length
    assert_equal 2, @san.san_nodes.length
  end
  def test_adding_two_san_interfaces
    @san = San.make
    @node = Node.make(:physical) 
    assert_no_difference('SanNode.count',"Fail to add node with no san connections") do
      xhr( :post, :add_node, {  :id => @san.id  ,:node => {:node_id => @node.id}} )
      assert_response :success
      assert_template '_node_list'
      assert_not_nil flash[:warning]
      assert_match /Error node has no nics/, flash[:warning]
    end
  end
  def test_remove_node
    @san = San.make
    @node = make_san_node
    assert_difference('SanNode.count', 2, "Adding two san connections") do
      xhr( :post, :add_node, {  :id => @san.id  ,:node => {:node_id => @node.id}} )
      assert_response :success
    end
    assert_difference('SanNode.count', -2, "Remove two san connections") do
      xhr(:post, :remove_node, { :id => @san.id  ,:node => @node.id })
      assert_response :success
      assert_template '_node_list'
      assert_no_match /Error/, flash[:notice]
      assert_no_match /Error/, flash[:warning]
      assert_no_match /Node/, flash[:warning]
      assert_nil flash[:notice] 
      assert_nil flash[:warning]
    end 
  end
end
