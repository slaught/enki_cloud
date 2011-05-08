
require 'test_helper'

class CnumachinemodelControllerTest < ActionController::TestCase

  def test_login
    login_as(make_admin_user)
    should_get_index(/Logged in as/)
  end

  def test_should_get_index
    should_get_index(/Not logged in/)
  end

  def should_get_index(usermsg)
    get :index
    assert_response :success
  end
  def test_should_show
    m = CnuMachineModel.make
    get :show, :id => m.id
    assert_response :success
    assert_template 'cnumachinemodel/show'
  end

end
