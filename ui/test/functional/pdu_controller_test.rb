
require 'test_helper'

class PduControllerTest < ActionController::TestCase

  def setup
    # login_as(make_admin_user)
  end

  def test_should_get_index
    get :list 
    assert_response :success
    assert_not_nil assigns(:pdus ) 
    get :index
    assert_response :redirect 
    assert_not_nil assigns(:pdus ) 
  end
  def test_should_show_pdu 
    pdu = Pdu.make
    get :show, :id => pdu.pdu_id 
    assert_response :success
    assert_not_nil assigns(:plugs)
  end

  def test_should_not_show_pdu 
    pdu = Node.make :virtual
    get :show, :id => pdu.node_id 
    assert_response :success
    assert_not_nil assigns(:plugs)
  end


end
