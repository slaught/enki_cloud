
require 'test_helper'

class SoftwareControllerTest < ActionController::TestCase

  def setup
    login_as(make_admin_user)
  end

  def test_should_get_index
    get :index
    assert_response :redirect 
    #assert_not_nil assigns(:distributions)
    get :list 
    assert_response :success
    assert_not_nil assigns(:distributions)
    assert_template 'software/list'
  end

  def test_should_show_software
    assert_raise ActionController::UnknownAction do
      get :show, :id => 1 
    end
  end
  
  def test_should_get_new
    get :new
    assert_response :success
  end
  def test_should_get_new_dist
    get :new_dist
    assert_response :success
  end

  def test_should_create_software
    b = OsVersion.plan(:kernel => '2.4.7-test')
    assert_difference('OsVersion.count') do
      post :create, :osversion => b
    end
    assert_redirected_to :action => 'list' , :controller => 'software'
  end
  def test_should_fail_to_create_software
    b = OsVersion.plan(:distribution => "no distro")
    assert_raise ActiveRecord::StatementInvalid do
      post :create, :osversion => b
    end
  end
  def test_doesnt_pass_all_to_create 
    assert_no_difference('OsVersion.count', 'Posting of invalid data') do
      post :create, :osversion => { } 
    end
  end
  def test_doesnt_pass_all_to_create_too
    post :create, :osversion => { } 
    # todo, check flash
    # flash[:warning] = "Missing Data: #{e.to_s}"
    assert_response :success
    assert_template 'software/new' 
    assert_not_nil flash[:warning], "no flash message" 
  end
  
  # todo: crate failed test for distro  
  def test_should_create_distro 
    b = Distribution.plan(:name => 'Test')
    assert_difference('Distribution.count') do
      post :create_dist, :distribution => b
    end
    assert_redirected_to :action => 'list' , :controller => 'software'
  end

  def test_should_edit
    o = OsVersion.make
    get :edit, :id => o.id
    assert_response :success
    assert_not_nil assigns(:osversion)
  end
  def test_should_edit_dist
    o = Distribution.make(:name => 'edit distro')
    get :edit_dist, :id => o.id
    assert_response :success
    assert_not_nil assigns(:distribution)
  end
  def test_should_update
    o = OsVersion.make
    kernel = "XXXtestXXX"
    post :update, :id => o.id, :osversion => { :kernel => kernel }
    assert_response :redirect
    assert_redirected_to :controller => "software", :action => "edit", :id => o.id
  end
  def test_should_update_dist
    o = Distribution.make(:name => 'edit distro')
    distro = "XXXtestXXX"
    post :update_dist, :id => o.id, :distribution => { :name => distro }
    assert_response :redirect
    assert_redirected_to :controller => "software", :action => "list"
  end
#  def update
#    @osversion = OsVersion.find(params[:id])
#    if @osversion.update_attributes(params[:osversion])
#      flash[:notice] = 'Os Version successfully updated.'
# 
#      redirect_to :action => 'edit', :id => @osversion
#    else
#      render :action => 'edit'
#    end
#  end

#  def update_dist
#    @distribution = Distribtuion.find(params[:id])
#    if @distribution.update_attributes(params[:distribtution])
#      flash[:notice] = 'Distribution successfully updated.'
#
#      redirect_to :action => 'list'
#    else
#      render :action => 'edit'
#    end
#  end
end
