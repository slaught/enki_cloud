require 'test_helper'

  
class NodeTest < ActionController::IntegrationTest

  def test_node_is_pdu_view
    login_as make_admin_user
    # Given the way pdus relate to nodes, we make the call to
    # the 'pdu' method to get the node we actually want the
    # view to test
    @node = Pdu.make.pdu
    Capybara::visit "/node/show/#{@node.id}"
    assert Capybara::page.has_content? "Plug Mappings"
    assert Capybara::page.has_css? "table.pdu"
  end

  def test_fan
    login_as make_admin_user
    Capybara::visit "/node/new"
    hostname = Sham.hostname
    Capybara::fill_in 'Hostname', :with => hostname
    Capybara::select 'fan', :from => 'node[node_type_id]'
    # select 'APC: ACF502 - Rack Fan', :from => 'node[model_id]'
    Capybara::click 'Create'
    assert Capybara::has_content? 'Node was successfully created'
    fan = Node.find_by_hostname hostname
    assert fan.mgmt_ip_address.nil?
  end

  def test_nav_admin_can_delete_nav_node
    @node = Node.make :virtual,
      :datacenter => Datacenter.find_by_name('nav')
    login_as make_nav_admin_user 
    Capybara::visit "/node/show/#{@node.id}"
    assert_difference('Node.count', -1) do
      Capybara::within(:css, 'ul.horiz_nav') do
        Capybara::click 'Delete'
      end
    end
  end

  def test_nav_admin_cant_delete_non_nav_node
    @node = Node.make :virtual,
      :datacenter => Datacenter.find_by_name('obr')
    login_as make_nav_admin_user
    Capybara::visit "/node/show/#{@node.id}"
    Capybara::within(:css, 'ul.horiz_nav') do
      assert_nil Capybara::find_link('Delete')
    end
    assert_no_difference('Node.count') do
      Capybara::visit "/node/destroy/#{@node.id}"
    end
    assert Capybara::has_content?(I18n.t :permission_denied)
  end

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
