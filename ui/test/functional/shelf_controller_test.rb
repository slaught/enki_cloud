require 'test_helper'

class ShelfControllerTest < ActionController::TestCase

  def test_db_loc 
    get :database_locations
    assert_response :success
    assert_nil flash[:warning]
    assert_nil flash[:error]
    assert_no_match /TemplateError/, @response.body
  end
  def test_activity
    get :activity 
    assert_response :success
    assert_not_nil assigns(:top_ten_users)
    assert_not_nil assigns(:versions) 
    assert_not_nil assigns(:old_versions) 
  end
  def test_warnings
    get :warnings
    assert_response :success
    assert_not_nil assigns(:empty_pdus)
    assert_not_nil assigns(:empty_switches)
    assert_not_nil assigns(:empty_serial)
    assert_not_nil assigns(:broken_lb )
    assert_not_nil assigns(:missing_model)
    assert_not_nil assigns(:missing_switch)
    assert_not_nil assigns(:missing_scs) 
    assert_not_nil assigns(:missing_pdu) 
    assert_not_nil assigns(:missing_os) 
    assert_not_nil assigns(:bad_equipment) 
  end
  def test_public_service
    should_get_services(:public_services)
  end
  def test_private_service
    should_get_services(:private_services)
  end
  def should_get_services(serv)
    get serv
    assert_response :success
    assert_not_nil assigns(:formatted) 
    assert_template "shelf/#{serv.to_s}"
  end

  def test_login_should_get_index
    login_as(make_admin_user)
    should_get_index
  end
  def test_should_get_index
      should_get_index
  end
  def should_get_index
    get :index
    assert_response :success
    assert_template 'shelf/index'
#    assert_equal 'layouts/welcome', @response.layout, "Wrong layout"
#    assert_select 'div#user_bar_frontpage ul li#user-bar-greeting' do |e|
#      assert_match usermsg, e.to_s 
#    end
#    assert_match usermsg,@response.body
  end

end
