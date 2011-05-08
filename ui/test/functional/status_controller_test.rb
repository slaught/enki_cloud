
require 'test_helper'

class StatusControllerTest < ActionController::TestCase
  
  def test_cluster_json
    make_active_cluster
    get :cluster, :format => "js"
    assert_response :success
    assert_template 'status/cluster'
    assert_nil @response.layout, "Wrong layout"
    assert_not_nil assigns(:clusters)
    assert_not_nil assigns(:portfwd)
    assert_not_nil assigns(:active_load_balancers)
    assert_not_nil assigns(:all_load_balancers)
    assert_not_nil assigns(:active_colos )
    assert_not_nil assigns(:other_colos )
    assert_not_nil assigns(:lbs)
    assert_not_nil assigns(:data)
    #puts @response.body
    assert_match /description/, @response.body
    assert_match /cluster_name/, @response.body
    assert_match /kindof/, @response.body
  end
end
