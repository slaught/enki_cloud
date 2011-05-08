require 'javascript_test_helper'

class NodeTest < JavascriptTest
  def test_add_nic_virtual
    login_as make_admin_user
    @node = create_node_by_controller :virtual
    Capybara::visit "/node/show/#{@node.id}"
    assert_difference('@node.nics.count') do
      Capybara::click 'Create Virtual Nics'
      assert Capybara::has_xpath?("//td[.='lan']")
    end
  end
  def test_add_nic_physical
    login_as make_admin_user
    @node = create_node_by_controller :physical
    Capybara::visit "/node/show/#{@node.id}"

    eth = Sham.eth
    Capybara::select 'Lan', :from => 'nic_network_type'
    Capybara::fill_in 'nic_port_name', :with => eth
    Capybara::fill_in 'nic_mac_address', :with => Sham.mac_address

    assert_difference('@node.nics.count') do
      Capybara::within(:css, '#add_nic'){ Capybara::click_button 'Add' }
      assert Capybara::has_xpath?("//td[.='#{eth}']")
    end
  end
  def test_remove_nic_physical
    login_as make_admin_user
    @node = create_node_by_controller :physical
    Capybara::visit "/node/show/#{@node.id}"
    assert_difference('@node.nics.count', -1) do
      disable_confirmation_dialogs
      click_button_titled 'Remove Nic'
      assert Capybara::has_no_xpath?("//td[.='eth0']")
    end
  end
  # TODO: Once Kris's functional test for this is sorted out
  # def test_remove_nic_virtual
  # end

  def test_add_switch_port
    login_as make_admin_user
    @switch = Node.make(:switch)
    @nsp = NetworkSwitchPort.plan(:switch_id => @switch.id)
    @node = Node.make(:physical, :datacenter_id => @switch.datacenter_id)
    Capybara::visit "/node/show/#{@node.id}"
    assert_difference('@node.network_switch_ports.count', 1) do
      Capybara::within(:css, '#add_switch_port_node') do
        Capybara::select @switch.to_label, :from => 'switch_port_switch_id'
        Capybara::fill_in 'switch_port_port', :with => @nsp[:port]
        Capybara::click 'Plug'
      end
      assert Capybara::has_xpath?("//td[.='#{@nsp[:port]}']")
    end
  end

  def test_remove_switch_port
    login_as make_admin_user
    @sw = NetworkSwitchPort.make
    port = @sw.port
    @node = @sw.node
    Capybara::visit "/node/show/#{@node.id}"
    assert_difference('@node.network_switch_ports.count', -1) do
      Capybara::locate(:css, "form#remove_switch_port_#{@sw.id}").find(:css, "input[type='image']").click
      ajax_safe{ assert Capybara::has_no_xpath?("//td[.='#{port}']") }
    end
  end

  def test_plug_serial_console
    login_as make_admin_user
    @node = create_node_by_controller :physical
    @scs = Node.make :serial_console, :datacenter => @node.datacenter
    Capybara::visit "/node/show/#{@node.id}"
    Capybara::within(:css, '#node_serial_consoles') do 
      Capybara::select @scs.to_label, :from => 'serial_console_scs_id'
      Capybara::fill_in 'serial_console_port', :with => Sham.scs_port
      assert_difference('@node.serial_consoles.count') do
        Capybara::click_button('Plug')
        assert Capybara::has_link?(@scs.to_label)
      end
    end
  end

  def test_unplug_serial_console
    login_as make_admin_user
    @scs = SerialConsole.make
    @node = @scs.node
    Capybara::visit "/node/show/#{@node.id}"
    Capybara::within(:css, '#node_serial_consoles') do 
      assert_difference('@node.serial_consoles.count', -1) do
        click_button_titled('Unplug')
        assert Capybara::has_no_link?(@scs.scs.to_label)
      end
    end
  end

  def test_map_to_xen_host
    login_as make_admin_user
    @xm = XenMapping.make
    @node = Node.make :virtual, :datacenter => @xm.host.datacenter
    @host = @xm.host
    Capybara::visit "/node/show/#{@node.id}"
    Capybara::select @host.to_label, :from => 'xen_mapping_host_id'
    Capybara::click 'Map to Xen Host'
    assert Capybara::has_link? @host.to_label
    assert Capybara::has_button? 'Unmap Xen Host'
    assert @node.reload.xen_domO == @host
  end

  def test_remove_from_xen_host
    login_as make_admin_user
    @xm = XenMapping.make
    @node = @xm.guest
    @host = @xm.host
    Capybara::visit "/node/show/#{@node.id}"
    Capybara::click 'Unmap Xen Host'
    Capybara::within(:css, '#xen'){ assert Capybara::has_no_link? @host.to_label }
    assert Capybara::has_button? 'Map to Xen Host'
    assert_raise ActiveRecord::RecordNotFound do
      XenMapping.find @xm.id
    end
  end

  def test_add_xen_guest
    login_as make_admin_user
    xm = XenMapping.make
    node = xm.host
    virtual = make_proper_node :virtual, :datacenter => node.datacenter 
    Capybara::visit "/node/show/#{node.id}"
    Capybara::select virtual.to_label, :from => 'xen_mapping_guest_id'
    Capybara::click 'Map to this Host'
    Capybara::within(:css, '#xen.node_data'){ assert Capybara::has_link? virtual.to_label }
    assert virtual.reload.xen_domO == node
  end

  def test_remove_xen_guest
    login_as make_admin_user
    xm = XenMapping.make
    node = xm.host
    guest = xm.guest
    Capybara::visit "/node/show/#{node.id}"
    Capybara::within(".//td[.='#{guest.to_label}']/..") do
      assert_difference('node.xen_guest_ids.count', -1) do
        Capybara::click 'Unassign guest'
        assert Capybara::has_no_link? guest.to_label
      end
    end
  end

  def test_plug_pdu
    login_as make_admin_user
    pdu = Pdu.make
    node = make_proper_node(:physical, :datacenter => pdu.pdu.datacenter, :model => CnuMachineModel.make)
    Capybara::visit "/node/show/#{node.id}"
    Capybara::within(:css, '#node_pdus.node_data') do
      assert_difference('node.pdus.count') do
        Capybara::select pdu.pdu.to_label, :from => 'pdu_pdu_id'
        Capybara::click 'Plug'
        assert Capybara::has_link? pdu.pdu.to_label
      end
    end
  end

  def test_unplug_pdu
    login_as make_admin_user
    pdu = Pdu.make
    node = pdu.node
    Capybara::visit "/node/show/#{node.id}"
    Capybara::within(:css, '#node_pdus.node_data') do
      assert_difference('node.pdus.count', -1) do
        Capybara::within(:css, "#remove_pdu_#{pdu.id}"){ click_button_titled 'Unplug' }
        assert Capybara::has_no_link? pdu.pdu.to_label
      end
    end
  end

  def test_unplug_node_from_this_pdu
    login_as make_admin_user
    pdu_join = Pdu.make
    pdu = pdu_join.pdu
    node = pdu_join.node
    Capybara::visit "/node/show/#{pdu.id}"
    Capybara::within(:css, '#node_pdus.node_data') do
      assert_difference('node.pdus.count', -1) do
        Capybara::within(:css, "#remove_pdu_#{pdu_join.id}"){ click_button_titled 'Unplug' }
        Capybara::wait_until{ Capybara::has_no_link? node.to_label }
      end
    end
  end

  def test_add_disk
    login_as make_admin_user
    node = make_proper_node :virtual
    # use a unique name to make sure it doesnt conflict with existing disks so we can check for its existence later
    disk = Disk.plan :file, :name => Sham.name
    Capybara::visit "/node/show/#{node.id}"
    Capybara::select 'Xen Disk', :from => 'disk_disk_type'
    Capybara::fill_in 'disk_name', :with => disk[:name] 
    Capybara::fill_in 'disk_mount_point', :with => disk[:mount_point]
    Capybara::fill_in 'disk_total_megabytes', :with => disk[:total_megabytes]
    assert_difference('node.disks.count') do
      Capybara::click 'Add Disk'
      Capybara::within(:css, 'table.disks'){
        assert Capybara::has_content? disk[:name]
        assert Capybara::has_content? disk[:mount_point]
        assert Capybara::has_content? disk[:total_megabytes].to_s
      }
    end
  end

  def test_remove_disk
    login_as make_admin_user
    node = make_proper_node :virtual
    # use a unique name to make sure it doesnt conflict with existing disks so we can check for its removal later
    disk = Disk.make :file, :name => Sham.name
    node.disks << disk
    Capybara::visit "/node/show/#{node.id}"
    assert Capybara::has_xpath? "//td[.='#{disk.name}']"
    assert_difference('node.disks.count', -1) do
      Capybara::locate("//form[@id='remove_disk_#{disk.id}']/input[@type='image']").click
      Capybara::within(:css, 'table.disks'){
        assert Capybara::has_no_content? disk.name
      }
    end
  end

  def test_add_to_cluster
    login_as make_admin_user
    cluster = make_active_cluster
    node = make_proper_node :virtual 
    Capybara::visit "/node/show/#{node.id}"
    Capybara::select cluster.cluster_name, :from => 'cluster_cluster_id'
    Capybara::click_button 'Add To Cluster'
    assert Capybara::has_link? cluster.cluster_name
  end

  def test_remove_from_cluster
    login_as make_admin_user
    cluster = make_active_cluster
    node = cluster.nodes.first 
    Capybara::visit "/node/show/#{node.id}"
    disable_confirmation_dialogs
    Capybara::locate("//a[.='#{cluster.cluster_name}']/../..//input[@title='Remove']").click
    assert Capybara::has_no_link? cluster.cluster_name
  end
end
