require 'test_helper'
 
class ClusterTest < ActionController::IntegrationTest

  def test_dba_can_move_postgres_services
    login_as _make_user_with_role('dba')
    c = make_active_cluster
    s = Service.make(:local_port => nil,
      :url => "postgresql://#{Sham.domain_name}/")
    Capybara::visit "/cluster/show/#{c.id}"
    Capybara::select s.to_label, :from => 'service[service_id]'
    assert_difference('c.services.count') do
      Capybara::click 'Add Service'
    end
    assert_not_nil Capybara::find_link s.name
    assert_difference('c.services.count', -1) do
      Capybara::within("//a[.='#{s.name}']/../..") do
        Capybara::click 'Remove'
      end
    end
    assert_nil Capybara::find_link s.name
  end

  def test_dba_cant_move_non_postgres_services
    login_as _make_user_with_role('dba')
    c = make_active_cluster
    s = Service.make(:local_port => nil)

    Capybara::visit "/cluster/show/#{c.id}"
    if Capybara::has_select?('service[service_id]')
      # make sure non-postgres service can't be selected
      assert ! Capybara::has_option?('service[service_id]', s.to_label)
    end

    s = c.services.detect{|s| s.ha_protocol != 'postgresql'}
    Capybara::within("//a[.='#{s.name}']/../..") do
      assert_nil Capybara::find_button 'Remove'
    end
  end

end
