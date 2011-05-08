
require 'test_helper'

class EthernetControllerTest < ActionController::TestCase

  def test_login
    login_as(make_admin_user)
    should_get_index
  end

  def test_should_get_index
    should_get_index
  end

  def should_get_index(x=nil)
    get :list 
    assert_response :success
    assert_template 'list' 
    assert_not_nil assigns(:ports)
  end

end
