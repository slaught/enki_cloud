
class NodeController < ApplicationController
  filter_access_to :all
  filter_access_to :destroy, :attribute_check => true do
    permitted_to!(:destroy, Node.find(params[:id]))
  end
  verify :method => :post, :only => [:update, :create, :remove_disk, :add_disk], :redirect_to => {:action => :list }


  def index
    redirect_to :action => "list"
  end
  def list
    @nodes = Node.active.paginate(:all, :page => params[:page], :per_page => 50)
    respond_to do |format|
      format.html { render }
      format.csv { render :csv => (@nodes = Node.active.all)}
    end


  end
  # 
  # allows searching by location
  def loc
    dc = sanitize_search(params[:id])
    dc_id = Datacenter.find_by_name(dc)
    @nodes =  Node.active.paginate_all_by_datacenter_id(dc_id, :page => params[:page])
    respond_to do |format|
      format.html { render :action => 'list' }
      format.csv { render :action => 'list', :csv => (@nodes = Node.active.in_datacenter(dc)) }
    end
  end
  # allows searching by node_type
  def  cls
    t = sanitize_search(params[:id])
    nt_id = NodeType.find_by_name(t) 
    @nodes =  Node.active.paginate_all_by_node_type_id(nt_id, :page => params[:page])
    render :action => 'list'
  end

  def host
    # check if search string was an ip address
    if params[:id][0] =~ /\A(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)(?:\.(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)){0,3}\.?\*?\z/
      @nodes = Node.paginate(:all, :conditions => ["HOST(ip_addresses.ip_address) like :ip or HOST(cluster_nodes.ip_address) like :ip",
        {:ip => params[:id][0].gsub("*", "%")}], :joins => 'LEFT JOIN "cluster_nodes" ON cluster_nodes.node_id = nodes.node_id 
        LEFT JOIN "ip_addresses" ON ip_addresses.ip_address_id = nodes.mgmt_ip_address_id', 
        :page => params[:page], :order => "hostname ASC")
    elsif params[:id][0] =~ /\A([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}\z/ then
      @nodes = Node.paginate(:all, :conditions => ["mac_address = :mac", {:mac => params[:id][0]}], 
          :joins => :nics, :page => params[:page], :order => "hostname ASC")
    else
      t = sanitize_search(params[:id][0])
      if t =~ /\.\w+/
        t_parts = t.split(".")
        dc_id = Datacenter.find_by_name(t_parts[1])
        @nodes = Node.paginate_all_by_datacenter_id(dc_id, :conditions => ["hostname like ?", "%#{t_parts[0]}%"], :page => params[:page],
          :order => "hostname ASC")
      else
        @nodes = Node.paginate(:all, :conditions => ["hostname like ?", "%#{t}%"], :page => params[:page], :order => "hostname ASC")
      params[:format] = nil # force default format since some people type: host.location
      end
    end
    render :action => 'list' 
  end

  def show
    @node = Node.find(params[:id])
    set_xen_info
    render 
  end
  def destroy
    @node = Node.find(params[:id])
		begin
			@node.remove
		rescue Exception
			flash[:error] = "There was a problem deleting node #{@node.hostname}<br/>"
			unless @node.is_removable?
				flash[:error] << "* The node is part of a cluster<br/>" unless @node.clusters.empty?
				flash[:error] << "* The node has network switch ports<br/>" unless @node.network_switch_ports.empty?
				flash[:error] << "* The node has PDUs<br/>" unless @node.pdus.empty?
				flash[:error] << "* The node has a SAN<br/>" unless @node.sans.empty?
				flash[:error] << "* The node has serial consoles<br/>" unless @node.serial_consoles.empty?
			end
  	end
    redirect_to :action => "list"
  end

  # GET /node/new
  def new
    @node = Node.new
    unless params[:fn_prefix].blank?
      @node.hostname = params[:fn_prefix].split('.')[0]
      @node.datacenter = Datacenter.find_by_name(params[:fn_prefix].split('.')[1])
    end
    @node.node_type = NodeType.find_by_name(params[:node_type]) if not params[:node_type].blank?
  end
  # GET /node/edit/1
  def edit
    @node  = Node.find(params[:id])
    render 
  end
  # POST /node 
  def create
    @p = params[:node]
    begin
      nt = @p[:node_type_id].to_i
      os = @p[:os_version_id].to_i
      @node = Node.create_node_by_id(@p) #@p[:serial_no], nt, os, @p[:hostname],@p[:datacenter])
      if @node.save()
        flash[:notice] = 'Node was successfully created.'
        return redirect_to( :action => 'show', :id=> @node )
      end
    rescue Exception => e
          flash.now[:warning] = "Error #{e.to_s}"
    rescue ActiveRecord::RecordNotFound => e
          flash.now[:warning] = "Missing Data: #{e.to_s}"
    end
    render :action => "new" 
  end
  # PUT /node/1
  def update
    @node = Node.find(params[:id])
    if @node.update_attributes(params[:node ])
      flash[:notice] = 'Node was successfully updated.'
        redirect_to :action => 'show', :id=> @node 
    else
        render :action => "edit" 
    end
  end
  def update_partial
    @node = Node.find(params[:id])
    attrib = params[:attribute]
    if @node.update_attributes({attrib.to_sym => params[:value]})
      @node.save
      flash[:notice] = 'Node was successfully updated.'
      # redirect_to :action => 'show', :id=> @node 
    else
      flash.now[:warning] = 'Failed to change.'
    end
    @node.reload
    render :text => @node.send(attrib.to_sym) 
  end

  def remove_nic
    @node = Node.find(params[:id].to_i)
    nic = Nic.find(params[:nic].to_i)
    if @node.nics.member?(nic) and not @node.node_type.is_virtual? then
      @node.nics.delete(nic) 
      nic.destroy
    else
      # NOTE: What happens when the node_type.is_virtual? The node can still
      # be in the nic, but we never actually remove it then. Broken? - kwhite1
      flash.now[:warning] = "Nic is not in Node"
    end
    render :partial => 'nics', :locals => {:node =>@node }
  end
  def add_nic
    @node = Node.find(params[:id].to_i)

    if @node.node_type.is_virtual? then 
        c = @node.create_virtual_nics()
        flash.now[:warning] = "Create #{c} new Nic#{ c > 1 ? 's' :''}"
    else
      mac_address = params[:nic][:mac_address]
      port_name = params[:nic][:port_name]
      type = params[:nic][:network_type]
      nic = Nic.find_by_mac_address(mac_address)
      if nic.nil? then
        if type =~ /san/ then
          @node.add_san_nic(mac_address, port_name)
        elsif type =~ /lan/ then
          @node.add_lan_nic(mac_address, port_name)
        else
          flash.now[:warning] = "Internal error: Invalid network type"
        end
      else
        flash.now[:warning] = "Nic already exists"
      end
    end
    render :partial => 'nics', :locals => {:node =>@node }
  end
  #
  # serial console support 
  def plug_serial_console
    @node = Node.find(params[:id].to_i)
    port = params[:serial_console][:port].to_i
    scs = Node.find(params[:serial_console][:scs_id].to_i)
    begin
      scs_id =  SerialConsole.plug_node_into_scs(@node, scs, port) 
      unless  scs_id and scs_id.save then
        flash.now[:warning] = "Error plugging in port: #{scs_id.errors.full_messages}"
      end 
    rescue Exception => e
        flash.now[:warning] = e.to_s 
    end
    render :partial => 'serial_consoles', :locals => {:node =>@node }
  end
  def unplug_serial_console
    id = params[:id]
    scs_id = params[:serial_consoles_id]
    @node = Node.find(params[:id].to_i)
    scs = SerialConsole.find(params[:serial_consoles_id].to_i)
    unless scs.node_id == @node.id then 
        flash.now[:warning] = "Error unplugging wrong node #{@node.id}/#{id} from #{scs_id}"
    else
      scs.destroy
      @node.reload
    end
    render :partial => 'serial_consoles', :locals => {:node =>@node }
  end
  #
  # PDU support 
  def plug_pdu 
    @node = Node.find(params[:id].to_i)
    port = params[:pdu][:outlet_no]
    pdu = Node.find(params[:pdu][:pdu_id].to_i)
    begin
      nsp = @node.plug_into(pdu, port)
      unless  nsp and nsp.save then
        flash.now[:warning] = "Error plugging in port: #{nsp.errors.full_messages}"
      end 
    rescue Exception => e
        flash.now[:warning] = e.to_s 
    end
    render :partial => 'pdus', :locals => {:node =>@node }
  end
  def unplug_pdu 
    id = params[:id]
    pdus_id = params[:pdus_id]
    @node = Node.find(params[:id].to_i)
    nsp = Pdu.find(params[:pdus_id].to_i)
    pdu_node = nsp.pdu if params[:is_pdu?]
    unless nsp.node_id == @node.id then 
      flash.now[:warning] = "Error unplugging wrong node #{@node.id}/#{id} from #{pdus_id} "
    else
      nsp.destroy
      @node.reload
    end
    # Passing custom params in based on which partial its coming from - kinda hackish. Problem is even
    # proper routes won't solve this...
    if params[:is_pdu?]
      render :partial => 'pdus', :locals => {:node => pdu_node }
    else
      render :partial => 'pdus', :locals => {:node =>@node }
    end
  end
  #
  # Switch Port
  def add_switch_port
    @node = Node.find(params[:id].to_i)
    port = params[:switch_port][:port]
    sw = Node.find(params[:switch_port][:switch_id].to_i)
    begin
      nsp = NetworkSwitchPort.plug(sw, @node, port)
      unless  nsp.save then
        flash.now[:warning] = "Error plugging in port: #{nsp.errors.full_messages}"
      end 
    rescue NetworkSwitchPortException => e
        flash.now[:warning] = e.to_s 
    end
    render :partial => 'switch_ports', :locals => {:node =>@node }
  end
  def remove_switch_port
    @node = Node.find(params[:id].to_i)
    # NOTE: :port is the :port_id
    nsp = NetworkSwitchPort.find(params[:port].to_i)
    nsp.destroy
    render :partial => 'switch_ports', :locals => {:node =>@node }
  end
  
  # todo: should disk record be deleted?
  # remove association for node but disk remains.
  def remove_disk
    modify_disks(params[:disk]) do |exists, node, disk|
      if exists.nil? then 
        flash.now[:warning] = "Error: no such Disk in Node"
      else
        # already enforced in _disks partial, but just in case...
        if node.node_type.is_virtual? and not (node.disks - [disk]).detect{|d| d.mount_point == '/'}
          flash.now[:warning] = "Error: A virtual node has to have a root disk!"
        else
          node.disks.delete(disk)
        end
      end
    end
  end
  def add_disk
    @node = Node.find(params[:id].to_i)
    p = params[:disk]
    block = nil

    if @node.disks.blank?
      begin
        @node.add_default_disk
      rescue Exception => e
        flash.now[:warning] = e.message
        nil
      end
    end

    @disk = if p[:disk_type] =~ /xen/
                Disk.create_xen_disk(p[:name], p[:mount_point], p[:total_megabytes])
            elsif p[:disk_type] =~ /san/
                Disk.create_iscsi(p[:name], p[:mount_point], p[:total_megabytes])
            else
              flash.now[:warning] = "Invalid disk_type #{p[:disk_type]}"
              nil
            end
    begin
      block = if p[:disk_type] =~ /xen/
                @node.next_disk_block(DiskType.file)
              elsif p[:disk_type] =~ /san/
                @node.next_disk_block(DiskType.iscsi)
              else
                flash.now[:warning] = "Invalid disk_type #{p[:disk_type]}"
                nil
              end
    rescue Exception => e
      flash.now[:warning] = e.message
      nil
    end

    if not @disk.nil? and not block.nil?
      if @disk.save
        @node.disks << @disk
        @disk.assign_block_name(@node, block)
      else
        x = "Error creating Disk: #{@disk.errors.full_messages}"
        flash.now[:warning] = x
      end
    end
    render :partial => 'disks', :locals => {:node =>@node }
  end

  def add_node_to_cluster
    modify_nodes(params[:cluster][:cluster_id]) do |cs_exists, cluster, node|
      if cs_exists then
        cluster.merge_node( node)
      else
        flash.now[:warning] = "Error node already in cluster"
      end
    end
  end

  def del_node_from_cluster
    modify_nodes(params[:cluster_id]) do |cs_exists, cluster, node|
      if cs_exists then
        flash.now[:warning] = "Error no such node in cluster"
      else
        cluster.nodes.delete(node)
      end
    end
  end

  def map_to_xen_host
    create_xen_mapping :host, params[:xen_mapping][:host_id].to_i
  end

  def add_xen_guest
    create_xen_mapping :guest, params[:xen_mapping][:guest_id].to_i
  end

  def remove_from_xen_host
    @node = Node.find(params[:id].to_i)
    XenMapping.remove_guest(@node)
    set_xen_info
    render :partial => 'xen', :locals => {:node => @node}
  end

  def remove_xen_guest
    @node = Node.find(params[:id].to_i)
    guest = Node.find(params[:guest_id].to_i)
    XenMapping.remove_guest(guest)
    @xen_guests = XenMapping.find_all_by_host_id(@node.id).map{|x| x.guest }
    render :partial => 'xen', :locals => {:node => @node}
  end

  def push_vlan
    @node = Node.find(params[:id].to_i)
    if RAILS_ENV == "production"
      Resque.enqueue(Pushvlan, @node.to_label)
    end
    flash[:notice] = "VLAN changes queued"
    redirect_to :action => "show", :id => @node
  end

  private
  def modify_nodes(cluster_id, &block)
    @node = Node.find(params[:id].to_i)
    @cluster = Cluster.find(cluster_id)
    @cs = ClusterNode.find_by_node_id_and_cluster_id(@node.id,@cluster.id)
    yield @cs.nil?, @cluster, @node
    render :partial => 'clusters', :locals => {:node => @node }
  end

  private
  def modify_disks(disk_id, &block)
    @node = Node.find(params[:id].to_i)
    @disk = Disk.find(disk_id.to_i)
    @exists = NodeDisk.find_by_node_id_and_disk_id(@node.id, @disk.id)
    yield @exists, @node , @disk
    render :partial => 'disks', :locals => {:node =>@node }
  end

  def sanitize_search(str)
     return nil unless str =~ /^\w+\s?-?\w*(\.[a-z]+)?$/
     str
  end

  def set_xen_info
    @xen_guests = []
    @xen_host = nil
    if @node.node_type.is_physical? then
      @xen_guests = XenMapping.find_all_by_host_id(@node.id).map{|x| x.guest }
    else
      xm = XenMapping.find_by_guest_id(@node.id)
      unless xm.nil?
        @xen_host = xm.host
      end
    end
  end

  # other == :host or :guest
  # other is a horrible variable name.
  def create_xen_mapping(other, other_id)
    @node = Node.find(params[:id].to_i)
    begin
      if other == :host
        @xen = XenMapping.move_guest(Node.find(other_id), @node)
      else
        @xen = XenMapping.move_guest(@node, Node.find(other_id))
      end
      if not @xen.save
        x = "Error creating Xen mapping: #{@xen.errors.full_messages}"
        flash.now[:warning] = x
      end
    rescue Exception => e
        flash.now[:warning] = "Error : #{e.to_s}"
    end
    set_xen_info
    render :partial => 'xen', :locals => {:node => @node}
  end
end
