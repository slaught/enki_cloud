
require 'test_helper'

# Re-raise errors caught by the controller.
#require 'xen_controller'
#class XenController; def rescue_action(e) raise e end; end

class XenControllerTest < ActionController::TestCase

  def test_truth
    assert true
  end

  def setup
    login_as(make_admin_user)
  end

  def test_should_get_index
    get :list 
    assert_response :success
    assert_not_nil assigns(:nodes ) 
  end
  def test_should_get_compare
    get :compare 
    assert_response :success
    assert_not_nil assigns(:nodes)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_xen 
    b = XenMapping.plan
    assert_difference('XenMapping.count') do
      post :create, :xen_mapping => b
    end
    assert_redirected_to :action => 'list' ,:controller => 'xen'
  end

  def test_should_destroy_xen
    @boot = XenMapping.make
    assert_difference('XenMapping.count', -1) do
      delete :destroy, :id => @boot.id 
    end
    #assert_redirected_to xen_path 
    assert_redirected_to :action => 'list' ,:controller => 'xen'
  end

  def test_should_map_to_host
    xm = XenMapping.plan
    assert_difference('XenMapping.count') do
      post :map_to_host, :host_id => xm[:host_id], :guest_fn_prefix => Node.find(xm[:guest_id]).to_label
    end
    assert_template :partial => '_xen_host_map', :count => 1
    assert flash.blank?
    assert_match /#{Node.find(xm[:guest_id]).to_label}/, @response.body
  end

  def test_should_create_new_mapping
    xm = XenMapping.plan
    assert_difference('XenMapping.count') do
      post :add_new_mapping, :host_id => xm[:host_id], :xen_mapping => {:guest_id => xm[:guest_id]}
    end
    assert_template :partial => '_xen_host_map', :count => 1
    assert flash.blank?
    assert_match /#{Node.find(xm[:guest_id]).to_label}/, @response.body
  end

  def test_should_unmap_guest
    xm = XenMapping.make
    assert_not_nil xm
    assert_difference('XenMapping.count', -1) do
      post :unmap_guest, :host_id => xm.host_id, :guest_fn_prefix => xm.guest.to_label
    end
    assert_template :partial => '_xen_host_map', :count => 1
    assert flash.blank?
    assert_no_match /#{Node.find(xm[:guest_id]).to_label}/, @response.body
  end

  def test_should_show_add_mapping_form
    host = Node.make :physical
    post :show_add_mapping_form, :host_id => host.id
    assert_template :partial => 'hide_add_mapping_form_button'
    assert_template :partial => '_add_mapping_form'
    assert_no_match /add[.]png/, @response.body
  end

  def test_should_hide_add_mapping_form
    host = Node.make :physical
    post :hide_add_mapping_form, :host_id => host.id
    assert_template :partial => 'show_add_mapping_form_button'
    assert_no_match /undo_arrow[.]png/, @response.body
  end

  def test_should_show_error
    xm = XenMapping.plan
    assert_no_difference('XenMapping.count') do
      # purposely unmap an unmapped host from itself
      post :unmap_guest, :host_id => xm[:host_id], :guest_fn_prefix => Node.find(xm[:host_id]).to_label
    end
    assert_template :partial => '_xen_host_map', :count => 1
    assert_template :partial => '_add_mapping_form'
    assert (not flash.blank?)
  end
end
