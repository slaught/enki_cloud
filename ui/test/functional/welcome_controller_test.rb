
require 'test_helper'

class WelcomeControllerTest < ActionController::TestCase

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
    assert_template 'welcome/index'
    assert_equal 'layouts/application', @response.layout, "Wrong layout"
    assert_select 'div#header ul li#user-bar-greeting' do |e|
      assert_match usermsg, e.to_s 
    end
    assert_match usermsg,@response.body
  end

end
