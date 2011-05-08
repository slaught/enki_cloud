require 'network_nodes'
class ShelfController < ApplicationController

  def database_locations
    @database_clusters = DatabaseCluster.find(:all)
    render 
  end
  def index
  end
  def warnings
    unless params[:id].nil?
      node_search = Node.in_datacenter(params[:id])
    else
      node_search = Node.active
    end
    @empty_pdus = []
    @empty_switches = []
    @empty_serial = []
    @broken_lb = []
    node_search.each do |n|
       if n.node_type.is_pdu? and 
          Pdu.count(:conditions =>{:pdu_id => n.id}).zero? then
          @empty_pdus << n
        end
        if n.node_type.is_switch? and 
            NetworkSwitchPort.count(:conditions => {:switch_id =>n.id}).zero? then
          @empty_switches << n
        end
        if n.node_type.is_serial_console? and 
            SerialConsole.count(:conditions => {:scs_id =>n.id}).zero? then
            @empty_serial << n
        end
        if n.node_type.is_loadbalancer? and n.pdus.empty? then
            @broken_lb << n
        end
    end 
    @missing_model = []
    @missing_scs   = []
    @missing_switch = []
    @missing_pdu = []
    @missing_os  = []
    node_search.each {|n|
      @missing_pdu << n if n.node_type.can_has_pdu? and n.pdus.empty? 
      @missing_scs << n if n.node_type.can_has_serial_console? and n.serial_consoles.empty? 
      @missing_switch << n if n.node_type.can_has_switch_port? and n.network_switch_ports.empty? 
      if n.model.nil? then
        @missing_model << n 
      elsif n.model.power_supplies.to_i != n.pdus.length then
        @missing_pdu << n
      end
    }
    @missing_os  = Node.find(:all, :conditions =>{:os_version_id => nil} ) 
    lb_vlans = Loadbalancers.load_balanced_vlans  # cache this so don't have to call everytime... abit expensive
    @without_lbs = Cluster.find_all_active.select{|c| not lb_vlans.include? c.vlan}
    @bad_equipment = CnuMachineModel.all.map{|m|
        if m.cpu_cores.nil? or m.ram.nil? or m.serial_console.nil? or m.power_supplies.nil?
            m
        end
        
    }.compact
  end

  def public_services
    @formatted = Service.public_services_used.sort_by{|i| i.first.first}
  end

  def private_services
    @formatted = Service.private_services_used.sort_by{|i| i.first.first}
  end
  def activity
    @sparksline = Version.sparksdata 
    @top_ten_users = Version.top_ten_users
    @versions = Version.find_latest
    @old_versions = Version.find_older(@versions.length)
  end
end
