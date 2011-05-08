
require 'test_helper'

class NodeControllerTest < ActionController::TestCase
#  def should_get_index(usermsg)
#    get :index
#    assert_response :success
#    assert_template 'welcome/index'
#    assert_equal 'layouts/welcome', @response.layout, "Wrong layout"
#    assert_select 'div#user_bar_frontpage ul li#user-bar-greeting' do |e|
#      assert_match usermsg, e.to_s 
#    end
#    assert_match usermsg,@response.body
#  end

  def setup
    login_as(make_admin_user)
  end

  def test_index
    assert_nothing_raised do
      get :index
      assert_response :redirect
      assert_redirected_to :controller => "node", :action => "list"
    end
  end

  def test_list
    @node = Node.make(:virtual)
    get :list 
    assert_response :success 
  end

  def test_new
    get :new 
    assert_response :success 
  end

  def test_edit
    @node = Node.make(:virtual)
    get :edit, :id => @node.node_id
    assert_response :success 
  end

  def test_update
    @node = Node.make(:virtual)
    newhostname = 'test1'
    post :update, :id=> @node.node_id, :node => {:hostname => newhostname }
    assert_response :redirect
    assert_redirected_to :controller => "node", :action => "show", :id => @node.node_id
  end

  def test_update_partial
  end

  def test_show
    @node = Node.make(:virtual)
    get :show, :id => @node.node_id
    assert_response :success 
    assert_tag :tag => 'h1', :child => /#{@node.hostname}/
  end

  def test_create
    @node = prepare_proper_node :virtual
    assert_not_nil Network.datacenter_mgmt_network(@node[:datacenter_id]) 
    assert_difference 'Node.count' do
      post :create, :node => @node
    end
    assert_nil flash[:warning]
    assert_redirect :controller => 'node', :action => "show" 
    assert_match /Node was successfully created/, flash[:notice]
    return Node.find_by_hostname_and_datacenter_id(@node[:hostname], @node[:datacenter_id])
  end

  def test_loc
    dc = Datacenter.find(:first)
    n = Node.make(:virtual, :datacenter_id => dc.id)
    get :loc, :id => dc.name
    assert_response :success
    assert_match /#{n.hostname}/, @response.body
    assert_template 'node/list'
  end

  def test_cls
    n = Node.make(:virtual)
    get :cls, :id => "virtual"
    assert_response :success
    assert_match /#{n.hostname}/, @response.body
    assert_template 'node/list'
  end

  def test_host_ip
    net = Network.make
    i = net.next_ip()
    n = Node.make(:virtual, :mgmt_ip_address => i )
    get :host, :id => i.to_s
    assert_response :success
    assert_match /#{n.hostname}/, @response.body
    assert_template 'node/list'
  end
  
  def test_host_hostname
    n1 = Node.make(:virtual, :hostname => "someserver01")
    n2 = Node.make(:virtual, :hostname => "someserver02")

    get :host, :id => "someserver"

    assert_response :success
    assert_match /#{n1.hostname}/, @response.body
    assert_match /#{n2.hostname}/, @response.body
    
    assert_template 'node/list'
  end

  def test_add_nic_virtual
    @node = create_node_by_controller :virtual
    @nic = Nic.plan
    assert_difference('Nic.count') do
      post :add_nic, :id => @node.node_id, :nic => @nic
      assert_response :success
    end
    assert_template :partial => '_nics'
  end

  def test_add_nic_physical
    @node = create_node_by_controller :physical
    @nic = Nic.plan(:mac_address => 'cc:70:ed:d3:a6:f9', :port_name => 'eth42', :network_type => 'lan')
    assert_difference('Nic.count') do
      post :add_nic, :id => @node.node_id, :nic => @nic
      assert_response :success
    end
    assert_template :partial => '_nics'
    assert_not_nil @node.nics.detect { |nic| nic.port_name == 'eth42' }
  end

  def test_remove_nic_physical
    @node = create_node_by_controller :physical
    @nic = Nic.make
    @node.nics << @nic
    assert_difference('@node.nics.count', -1) do
      post :remove_nic, :id => @node.node_id, :nic => @nic.nic_id
      assert_response :success
    end
    assert_template :partial => '_nics'
  end

# FIXME: Uncomment when we've established WHAT we want to do to nics that
# are on virtual nodes. Right now, the controller flashes a message that
# says the nic isn't attached to the node. Even if it is?
  #def test_remove_nic_virtual
    #@node = create_node_by_controller :virtual
    #@nic = Nic.make
    #@node.nics << @nic
    #assert_difference('@node.nics.count', -1) do
      #post :remove_nic, :id => @node.node_id, :nic => @nic.nic_id
      #assert_response :success
    #end
    #!assert_template :partial => '_nics'
  #end

  def test_plug_serial_console
    @node = create_node_by_controller :physical
    @scs = SerialConsole.make
    assert_nothing_raised do
        post :plug_serial_console, :id => @node.node_id, :serial_console => @scs
        assert_match /Error plugging in port/, @response.body
        assert_template :partial => '_serial_consoles'
    end
    @scs = SerialConsole.plan
    assert_nothing_raised do
      assert_difference('SerialConsole.count', 1) do
        post :plug_serial_console, :id => @node.node_id, :serial_console => @scs
        assert_template :partial => '_serial_consoles'
      end
    end
  end

  def test_unplug_serial_console
    # Failure cases - Checked first to save a SerialConsole.make
    @scs = SerialConsole.make
    assert_nothing_raised do
      post :unplug_serial_console, :id => @scs.node_id.to_i + 1, :serial_consoles_id => @scs.id
      assert_template :partial => '_serial_consoles'
      assert_match /Error unplugging wrong node/, @response.body
    end
    # Clean run
    assert_nothing_raised do
      post :unplug_serial_console, :id => @scs.node_id, :serial_consoles_id => @scs.id
      assert_template :partial => '_serial_consoles'
    end
    assert_raise ActiveRecord::RecordNotFound do
      # NOTE: This may be better done by doing a find with the appropriate
      # conditions for node_id. If we choose to just dissasociate down the
      # road then it's still valid.
      SerialConsole.find(@scs.id)
    end
  end

  def test_plug_pdu
    @node = Node.make(:physical)
    @pdu = Pdu.make
    assert_nothing_raised do
      post :plug_pdu, :id => @node.node_id, :pdu => @pdu
      assert_match /Error plugging in port/, @response.body
      assert_template :partial => '_pdus'
    end
    @node = Node.make(:physical)
    @pdu = Pdu.plan
    assert_nothing_raised do
      assert_difference('Pdu.count', 1) do
        post :plug_pdu, :id => @node.node_id, :pdu => @pdu
        assert_template :partial => '_pdus'
      end
    end
  end

  def test_unplug_pdu
    # Failure cases
    @pdu = Pdu.make
    assert_nothing_raised do
      post :unplug_pdu, :id => @pdu.node.node_id.to_i + 1, :pdus_id => @pdu.id
      assert_template :partial => '_pdus'
      assert_match /Error unplugging wrong node/, @response.body
    end
    # Clean run
    assert_nothing_raised do
      post :unplug_pdu, :id => @pdu.node_id, :pdus_id => @pdu.id
      assert_template :partial => '_pdus'
    end
    assert_raise ActiveRecord::RecordNotFound do
      Pdu.find(@pdu.id)
    end
  end

  def test_add_switch_port
    @node = create_node_by_controller :physical
    @nsp = NetworkSwitchPort.make
    assert_nothing_raised do
        post :add_switch_port, :id => @node.node_id, :switch_port => @nsp
        assert_match /Error plugging in port/, @response.body
        assert_template :partial => '_switch_ports'
    end
    @switch = Node.make(:switch)
    @nsp = NetworkSwitchPort.plan(:switch_id => @switch.id)
    @node = Node.make(:physical, :datacenter_id => @switch.datacenter_id)
    assert_nothing_raised do
      assert_difference('NetworkSwitchPort.count', 1) do
        post :add_switch_port, :id => @node.node_id, :switch_port => @nsp
        assert_template :partial => '_switch_ports'
      end
    end
  end

  def test_remove_switch_port
    @sw = NetworkSwitchPort.make
    assert_nothing_raised do
      post :remove_switch_port, :id => @sw.node_id, :port => @sw.id
      assert_template :partial => '_switch_ports'
    end
    assert_raise ActiveRecord::RecordNotFound do
      NetworkSwitchPort.find(@sw.id)
    end
  end

  def test_add_disk
    @node = create_node_by_controller :virtual
    @disk = Disk.plan :iscsi, :disk_type => 'sandisk'
    assert_difference('Disk.count') do
      post :add_disk, :id => @node.node_id, :disk => @disk
      assert_response :success
    end
    assert_template :partial => '_disks'
    assert_not_nil @node.node_disks.detect{|nd| nd.block_name == "sdb"}
  end

  def test_remove_disk
    @node = create_node_by_controller :virtual
    @disk = Disk.make :file
    @node.disks << @disk
    assert_difference('@node.disks.count', -1) do
      post :remove_disk, :id => @node.node_id, :disk => @disk.id
      assert_response :success
    end
    assert_template :partial => '_disks'
  end

  def test_destroy
    @node = Node.make(:virtual)
    assert_nothing_raised do
      Node.find(@node.node_id)
    end
    assert_nothing_raised do
      post :destroy, :id => @node.node_id
      assert_equal Hash.new, flash
      assert_response :redirect
      assert_redirected_to :controller => "node", :action => "list"
    end
    assert_raise ActiveRecord::RecordNotFound do
      Node.find(@node.node_id)
    end
  end

  def test_add_disk_increment_block_name_basic
    add_disk_increment_block_name DiskType.file, DiskType.file, "sda2", "sda3"
    add_disk_increment_block_name DiskType.file, DiskType.file, "sda2", "sda3", true
  end
  def test_add_disk_increment_block_name_iscsi
    add_disk_increment_block_name DiskType.iscsi, DiskType.iscsi, "sda", "sdb"
    add_disk_increment_block_name DiskType.iscsi, DiskType.iscsi, "sda", "sdb", true
  end
  def test_add_disk_increment_block_name_iscsi_sda1_to_sdb
    add_disk_increment_block_name DiskType.iscsi, DiskType.iscsi, "sda1", "sdb"
    add_disk_increment_block_name DiskType.iscsi, DiskType.iscsi, "sda1", "sdb", true
  end
  def test_add_disk_increment_block_name_xen_from_iscsi
    add_disk_increment_block_name DiskType.iscsi, DiskType.file, "sda2", "sdb"
    add_disk_increment_block_name DiskType.iscsi, DiskType.file, "sda2", "sdb", true
  end
  def test_add_disk_increment_block_name_iscsi_from_xen
    add_disk_increment_block_name DiskType.file, DiskType.iscsi, "sda1", "sdb"
    add_disk_increment_block_name DiskType.file, DiskType.iscsi, "sda1", "sdb", true
  end
  def test_add_disk_increment_block_name_digit_overflow
    add_disk_increment_block_name DiskType.file, DiskType.file, "sda15", "sdb"
    add_disk_increment_block_name DiskType.file, DiskType.file, "sda15", "sdb", true
  end

  def test_add_disk_already_at_largest
    @disk = Disk.make :file

    @node = Node.make :virtual
    NodeDisk.make :node => @node, :disk => @disk, :block_name => "sddx15"

    @disk = Disk.plan :file, :disk_type => 'xendisk'

    post :add_disk, :id => @node.node_id, :disk => @disk
    #FIXME: will always pass even if bad, should compare {} or Hash.new
    #flash is (apparently) never nil, but an empty hash
    assert_not_nil flash
  end

  def test_add_node_to_cluster
    @node = Node.make(:virtual)
    @cluster = Cluster.make
    assert_nothing_raised do
      post :add_node_to_cluster, :cluster => @cluster, :id => @node.node_id
      assert_template :partial => '_clusters'
      assert @cluster.reload.nodes.include? @node
    end
    assert_nothing_raised do
      #We need to trigger a failure...
      @node = Node.make(:virtual)
      (@cluster.nodes << @node) and @cluster.save!
      post :add_node_to_cluster, :cluster => @cluster, :id => @node.node_id
      assert_template :partial => '_clusters'
      # FIXME: This doesn't show, like it is supposed to. BUG.
      assert_match /Error node already in cluster/, @response.body, 'FIXME: kris expects this to fail'
    end
  end

  def test_map_to_xen_host
    #FIXME: If node is :physical we fail silentley across the board
    @node = Node.make :virtual
    @xm = XenMapping.plan
    assert_nothing_raised do
      post :map_to_xen_host, :id => @node.node_id, :xen_mapping => @xm
      assert_template :partial => '_xen'
      puts @response.body
      assert_instance_of XenMapping,
                         XenMapping.find(:first, :conditions => {
                                            :guest_id => @node.node_id,
                                            :host_id => @xm[:host_id] })
    end
  end

  def test_add_xen_guest
    @node = Node.make :virtual
    @xm = XenMapping.make
    assert_nothing_raised do
      post :map_to_xen_host, :id => @node.node_id, :xen_mapping => @xm
      assert_template :partial => '_xen'
    end
  end

  def test_remove_from_xen_host
    @xm = XenMapping.make
    assert_nothing_raised do
      post :remove_from_xen_host, :id => @xm.guest_id
      assert_response :success
      assert_template :partial => '_xen'
    end
    assert_raise ActiveRecord::RecordNotFound do
      XenMapping.find @xm.id
    end
  end

  def test_remove_xen_guest
    @xm = XenMapping.make
    assert_nothing_raised do 
      post :remove_xen_guest, :id => @xm.host_id, :guest_id => @xm.guest_id
      assert_response :success
      assert_template :partial => '_xen'
    end
    assert_raise ActiveRecord::RecordNotFound do
      XenMapping.find @xm.id
    end
  end

  #def test_modify_nodes
  #end

  #def test_modify_disks
  #end

  #def test_sanitize_search
  #end

  #def test_set_xen_info
  #end

  #def test_create_xen_mapping
  #end

private
  def add_disk_increment_block_name(existing_type, adding_type, existing_block, assert_block, physical=false)
    if existing_type == DiskType.file
      @disk = Disk.make :file
    else
      @disk = Disk.make :iscsi
    end

    @node = physical ? Node.make(:physical) : Node.make(:virtual)
    NodeDisk.make :node => @node, :disk => @disk, :block_name => existing_block.to_s

    if adding_type == DiskType.file
      @disk = Disk.plan :file, :disk_type => 'xendisk'
    else
      @disk = Disk.plan :iscsi, :disk_type => 'sandisk'
    end

    post :add_disk, :id => @node.node_id, :disk => @disk
    assert_response :success
    assert_nil flash[:error]
    assert @node.disks.detect{|d| d.block_name(@node) == assert_block}
    assert_template :partial => '_disks'
  end

  def random_element(arr)
    arr.sort_by{ rand }.first
  end
public

end
