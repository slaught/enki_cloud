#!/usr/bin/ruby 


require 'rubygems'
require 'active_record'
require 'active_support'

require 'date'
require 'ipaddr'
#VERBOSE = true


class NodeException < Exception
end
class SanException < Exception
end
class NetworkSwitchPortException < Exception
end

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      def supports_insert_with_returning?
        false 
      end
    end
  end
end

#module Associations    
#  class HasAndBelongsToManyAssociation
#    def update_attributes(record, join_attributes = {})
#      if record.is_a? ActiveRecord::Base
#        record_id = record.id
#      else
#        record_id = record
#      end
#      cols, vals = [], []
#      join_attributes.each do | key, val |
#        cols << key.to_s
#        vals << val
#      end
#      col_string = cols.join(' = ?, ')
#      @owner.connection().update(sanitize_sql(["UPDATE #{@join_table} SET #{col_string} = ? WHERE #{@association_class_primary_key_name} = ? AND #{@association_foreign_key} = ?", vals, @owner.id, record_id].flatten), "Update Attributes")
#    end   
#  end
#end

class Cluster < ActiveRecord::Base
  set_primary_key 'cluster_id'
  has_paper_trail

  has_and_belongs_to_many :nodes, :join_table => 'cluster_nodes',:order => 'hostname'
  has_many :cluster_nodes
  has_many :cluster_services
  has_many :services, :through => :cluster_services

  validates_length_of :cluster_name, :within  => 2..16
  validates_format_of :cluster_name, :with => /\A[a-z][a-z_0-9]*[a-z0-9]\Z/ , :message => 'has spaces or capital letters'
  validates_format_of :cluster_name, :with => /[^_]\Z/, :message => "has underscore at the end"
  validates_format_of :cluster_name, :with => /\A[^_]/, :message => "starts with an underscore"
  validates_format_of :cluster_name, :with => /\A[^ \t]+\Z/, :message => "has spaces"
  validates_format_of :cluster_name, :with => /^[^A-Z]+$/, :message => "has capital letters", :on => :create
  validates_length_of :description , :minimum => 5
  validates_numericality_of :vlan, :only_integer => true, :greater_than_or_equal_to => 1, :less_than => 4096
  validates_numericality_of :fw_mark, :only_integer => true, :greater_than_or_equal_to => 1, :less_than => (2**31 -1 ), :allow_nil => true

  before_validation :clear_empty_attrs
  before_update :update_fwmark, :if => "vlan_was != vlan"

  extend CNU::Conversion

  def title
      self.description # + ' ' + self.cluster_services.map { |cs| cs.service.description }.join(' ')
  end
  def name
    cluster_name
  end
  def to_label
    cluster_name
  end
  def node_ip_addresses
      self.cluster_nodes.map {|cn| if cn.node.is_server? then cn.ip_address else nil end }.compact
  end
  def ha_ip_address
      ha_ip_addresses
  end
  def ha_ip_addresses
      self.cluster_services.map { |cs| cs.service.ip_address }.uniq
  end
  def active?
    (not fw_mark.nil? and fw_mark) and (not self.cluster_services.empty?) and (not self.cluster_nodes.empty?)
  end
  def ldirectord_cfg_filename
    "ldirectord_#{cluster_name}.cfg" 
  end
  def self.find_by_name(s)
      c = self.find_by_cluster_name(s)
      return c unless c.nil?
      c = find(:all, :conditions => ["cluster_name like '%%#{s}%%'"])
      return c
  end
  # Do not know if it is possible to turn this into a named_scope 
  # named_scope :active,:join?? :conditions => ["fw_mark is not null"], :order => :hostname 
  def self.find_all_active(sort_by_name=false)
    if sort_by_name
      find(:all, :order => :cluster_name).select {|c| c.active?  }
    else
      find(:all, :order => :cluster_id).select {|c| c.active?  }
    end
  end
  def self.next_forward_mark(p_vlan)
    min = ip2dec(vlan_fallback_ip(p_vlan))
    max = ip2dec("127.%d.255.255" % p_vlan)
    existing_fwms = Cluster.find(:all,
      :conditions => ["fw_mark >= ? and fw_mark <= ?", min, max]).map{|c| c.fw_mark}
    potential_fwms = (min..max).to_a - (existing_fwms)
    raise Exception.new("No more forward marks available in this vlan range!") if potential_fwms.empty?
    potential_fwms.first
  end
  def self.create_cluster(p_name,p_desc, p_vlan, p_ip_range, load_balance=true)
    forward_mark = next_forward_mark(p_vlan)
    forward_mark = nil if p_vlan.to_i > 255 
    lb = load_balance 
    create({:cluster_name => p_name, :description => p_desc, :vlan => p_vlan,
          :ip_range => p_ip_range, :fw_mark => forward_mark, :load_balanced => lb})
  end
  def self.find_mgmt_cluster_by_location(location)
    loc = location.downcase.strip()
    Cluster.find_all_mgmt.select{|c| c.cluster_name =~ /#{loc}/ }.first
  end
  def cluster_type
    unless self.active?
      'not active'
    else
      if self.load_balanced?
       'Load Balanced'
      else
       'Port Forward'
      end
    end
  end
  def self.add_node_to_cluster(cluster, node, node_ip=nil)
      if cluster.nil? 
        raise Exception.new("error: cluster is nil") 
      end
      if node.nil? 
        raise Exception.new("error: node is nil") 
      end
      unless cluster.class == Cluster then
        raise Exception.new("error: #{cluster.inspect} is not a cluster ") 
      end
      unless node.class == Node then
        raise Exception.new('error: add_node(node,node_ip)')
      end
      node_ip = cluster.next_ip() if node_ip.nil? 
      ClusterNode.create({:cluster_id => cluster.cluster_id, :node_id => node.node_id, :ip_address => node_ip})
      node_ip
  end
  def merge_node(node)
      candidate_clusters = node.clusters.select{|c|  c.vlan == self.vlan }
      if candidate_clusters.empty? then
        add_node(node)
      else
        add_node(node,candidate_clusters.first.ip_address)
      end
  end
  def add_node(node, node_ip=nil)
      unless node.class == Node then
        puts "error: #{node} is not a Node object. add_node(node,node_ip)"
        return nil
      end
      if self.nodes(true).member? node then 
          return nil
      end
      node_ip = next_ip() if node_ip.nil? 
      ClusterNode.create({:cluster_id => cluster_id, :node_id => node.id, :ip_address => node_ip})
      node.reload
      node.create_virtual_nics()
      self
  end
  def add_gen_int_node(node)
      unless node.class == Node then
        raise Exception.new('error: add_node(node)')
      end

      gen_int = Cluster.find_by_cluster_name('gen_int')
      unless gen_int.ip_range == self.ip_range and gen_int.vlan == self.vlan then
        raise Exception.new("Cluster(#{name}) is not on the gen_int network segment")
      end
      cn = ClusterNode.find_by_cluster_id_and_node_id(gen_int.id, node.id)
      if cn.nil? or cn.ip_address.nil? or cn.ip_address !~ /10.8.101./ then
        raise Exception.new("Node (#{node.hostname}) is not on the gen_int network segment")
      end
#      cn.cluster_id = self.cluster_id
#      cn.  #f
      Cluster._update(["UPDATE cluster_nodes SET \"cluster_id\" = ?  WHERE cluster_id = ? AND node_id = ?", cluster_id, gen_int.cluster_id, node.node_id])
  end
  def take_node(node, src)
      unless node.class == Node and src.class == Cluster then
        raise Exception.new('error: take_node(node,cluster)')
      end
      
      unless src.ip_range == self.ip_range and src.vlan == self.vlan then
        raise Exception.new("Cluster(#{name}) is not on the #{src.cluster_name} network segment")
      end
      cn = ClusterNode.find_by_cluster_id_and_node_id(src.id, node.id)
      if cn.nil? or cn.ip_address.nil? or cn.ip_address !~ %r/#{network_prefix}/ then
        puts "nil? #{cn.nil?} or #{cn.ip_address.nil?} address or #{ cn.ip_address} !~ #{%r/#{network_prefix}/} match"
        raise Exception.new("Node (#{node.hostname}) is not assigned an addresson the #{ip_range} network.")
      end
      Cluster._update(["UPDATE cluster_nodes SET \"cluster_id\" = ?  WHERE cluster_id = ? AND node_id = ?", cluster_id, src.cluster_id, node.node_id])
  end
  def next_ip
    connection.select_value("select cnu_net.next_cluster_ip_address(#{cluster_id})")
  end
  def new_next_ip()
    query  =  %Q[SELECT '#{ip_range}'::inet + s as ip_address 
            FROM generate_series(20, broadcast('#{ip_range}') - network('#{ip_range}'),1) as s(a) 
            EXCEPT (SELECT ip_address FROM cluster_nodes 
            WHERE cluster_id = #{cluster_id} GROUP BY 1 ORDER BY 1) limit 1]
    s = find_by_sql(query).first
    if s.nil? then
      raise ActiveRecord::RecordNotFound.new("No more IP address in network #{ip_ranage}")
    else
      s.ip_address
    end
  end
  def self.find_description(forward_mark, ha_ip_address ) 
#  Cluster.find_by_fw_mark(forward_mark).cluster_services.by_sql(
#    "select into cluster_desc s.description 
#       from services s join cluster_services cs on s.service_id = cs.service_id 
#      join clusters c on c.cluster_id = cs.cluster_id
#      where c.fw_mark = forward_mark and s.ip_address = ha_ip_address;
#    ")
#  return cluster_desc 
    nil
  end
  def add_service(service_name)
#    svc = Service.find_all_by_service_name(service_name)
#    svc 
#      ClusterService.create({:cluster_id => cluster_id, :service_id => s.id })
#  for rec in select service_id from services where name = service_in LOOP 
#    insert into cnu_net.cluster_services (cluster_id, service_id ) 
#      values ( cid, rec.service_id );
#
    nil
  end
  def no_lb_assigned?
    # TODO: fix me 
    # true if active? and not load_balanced_vlans.include? vlan
    return false 
  end
  def self.find_all_mgmt
    Cluster.find_all_by_vlan(4000)
  end
  def self.fwmark_in_range?(c)
    return true if c.vlan.nil? or c.fw_mark.nil?
    min = ip2dec(vlan_fallback_ip(c.vlan))
    max = ip2dec("127.%d.255.255" % c.vlan)
    (min..max).include? c.fw_mark
  end
  protected
  def self._update(a)
    connection.update(sanitize_sql_array(a.flatten), "Update Attributes")
  end
  protected
  def network_prefix
    ip_range.split('/').first.split('.')[0,3].join('.')

  end
  private
  def self.vlan_fallback_ip(vlan)
    "127.%d.0.1" % vlan
  end
  def vlan_fallback_ip(vlan)
    Cluster.vlan_fallback_ip(vlan) 
  end
  def update_fwmark
    self.fw_mark = Cluster.next_forward_mark(vlan)
  end
end

class ClusterService <ActiveRecord::Base
  before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail
  belongs_to :service
  belongs_to :cluster
end
class ClusterNode <ActiveRecord::Base
  before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail
  # has_many :nodes 
  belongs_to :node
  belongs_to :cluster
  def change_ip(new_ip)
      ClusterNode._update(["UPDATE cluster_nodes SET \"ip_address\" = ?  WHERE cluster_id = ? AND node_id = ?", new_ip, cluster_id, node_id])
  end
 protected
  def self._update(a)
    connection.update(sanitize_sql_array(a.flatten), "Update Attributes")
  end
end
class ClusterConfiguration < ActiveRecord::Base
# SELECT c.cluster_name AS c, c.vlan, c.ip_range, s.name, c.fw_mark, s.url,
# s.ip_address AS ha_ip_address, s.service_port AS port, s.local_port,
# s.availability AS area, cn.ip_address AS node_ip, n.hostname AS host,
# n.mgmt_ip_address AS mgmt, p.proto, n.node_id, c.load_balanced AS is_lb
#   FROM services s
#   JOIN cluster_services cs ON s.service_id = cs.service_id
#   JOIN clusters c ON c.cluster_id = cs.cluster_id
#   JOIN cluster_nodes cn ON c.cluster_id = cn.cluster_id
#   JOIN nodes n ON n.node_id = cn.node_id
#   JOIN protocols p ON p.protocol_id = s.protocol_id;
#
# fks = FK.find_by_sql("select * from pg_constraint where conrelid = '#{lt.relname}'::regclass")
#puts fks[1].conkey.class
  belongs_to :node
  def net_service(node_type='physical')
    if node_type == 'virtual' then
      net_type =  'eth'
    else
      net_type =  'vlan'
    end
    [ha_ip_address , port ,
        proto, localport,
       "#{net_type}#{vlan}" # local interface
    ].map {|e| e.to_s.strip() }
  end
  def localport
    if local_port.nil?
      port 
    else
      local_port
    end
  end
  def self.find_all_ha_net_services
     ClusterConfiguration.find(:all, :conditions => ["fw_mark is not null and port is not null"]).map{ |cc| cc.net_service }.uniq
  end
end
class Nic < ActiveRecord::Base
  set_primary_key 'nic_id'
  has_paper_trail
  before_save :strip_port_whitespace

	has_and_belongs_to_many :nodes, :join_table => "node_nics"
  def lan?
    network_type == 'lan' 
  end
  def san?
    network_type == 'san' 
  end
  def udev_rule
   mac = mac_address.downcase.strip()
   port = port_name.downcase.strip()
  %Q(SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="#{mac}", ATTR{type}=="1", KERNEL=="eth*", NAME="#{port}")
  end
  def self.mk_xen_mac()
    return "00:16:3E:%02X:%02X:%02X" % [rand(0x7f), rand(0xff), rand(0xff)]
  end
  private
    def strip_port_whitespace
      self.port_name = self.port_name.gsub(/\s/, "")
    end
end

class NodeNic < ActiveRecord::Base
  has_paper_trail
end

class Node < ActiveRecord::Base
  
  set_primary_key 'node_id'
  has_paper_trail
  named_scope :active, :joins => :node_type, :conditions => ["node_type.node_type <> ?", 'dummy'], :order => :hostname
  named_scope :physical, :joins => :node_type, :conditions => ["node_type.node_type = ? or node_type.node_type = ?", 'physical', 'load balancer']
  named_scope :in_datacenter, lambda { |dc|
    if dc.is_a? String
      { :joins => :datacenter, :conditions => ["datacenters.name = ?", dc ] }
    else
      { :conditions => ["nodes.datacenter_id = ?", dc] }
    end
  }
  named_scope :dom0s, :joins=> :xen_guests, :order => "hostname ASC"

  named_scope :node_type, lambda { |nt|
    { :joins => :node_type, :conditions => ["node_type.node_type = ?", nt] }
  }

  validates_format_of :hostname, :with => /\A[a-z0-9][-a-z0-9]*[a-z0-9]+\Z/,:message =>'is the shortname only'
  validates_format_of :hostname, :with => /\A[^\.]+\Z/,:message =>'has no periods'
#  validates_format_of :mgmt_ip_address, :with => /\A\d+\.\d+\.\d+\.\d+(\/\d+)?\Z/, 
#                                      :message =>'is not a valid IP address (0.0.0.0/0)', :on => :update
#  validates_uniqueness_of :mgmt_ip_address, :on => :update, :allow_nil => true
#  validate_on_update :mgmt_ip_address_must_be_unique, :allow_nil => true
  validates_presence_of :datacenter_id
  validates_presence_of :node_type_id
  validates_presence_of :hostname 
  validates_uniqueness_of :hostname ,:scope => :datacenter_id, :case_sensitive => false
#  validates_inclusion_of :node_type_id , :in => %w(public campus),  :message => "{{value}} is not 'public' or 'campus'" 


  has_and_belongs_to_many  :nics, :join_table => 'node_nics'
  belongs_to :node_type
  has_many   :cluster_nodes
  has_many   :san_nodes
  has_and_belongs_to_many :clusters , :join_table => 'cluster_nodes' 
  has_and_belongs_to_many :sans, :join_table => 'san_nodes' 
  belongs_to :os_version
  belongs_to :location
  belongs_to :datacenter
  belongs_to :mgmt_ip_address,  :class_name => "IpAddress", :foreign_key => 'mgmt_ip_address_id'
  has_many :cluster_configurations

  belongs_to :model, :foreign_key => 'model_id', :class_name => "CnuMachineModel"
  # xen mapping
  has_one :xen_host, :foreign_key => 'guest_id', :class_name => "XenMapping"
  has_one :xen_guest, :foreign_key => 'guest_id', :class_name => "XenMapping"
  has_many :xen_guests, :foreign_key => 'host_id', :class_name => "XenMapping"

  has_one :live_xen_host, :foreign_key => 'client_id', :class_name => "LiveXenMap"
  has_many :live_xen_guests, :foreign_key => 'host_id', :class_name => "LiveXenMap"

  has_many :domus, :through => :xen_guests, :source => :guest
  has_many :live_domus, :through => :live_xen_guests, :source => :domu

  has_one :domo, :through => :xen_host, :source => :host
  has_one :live_domo, :through => :live_xen_host, :source => :domo

  # pdu mappings
#  has_one :pdu_node, :foreign_key => 'node_id'
  has_many :pdus , :foreign_key => 'node_id'

  has_many :serial_consoles, :foreign_key => 'node_id'

  # disks
  has_many :node_disks
  # has_and_belongs_to_many  :disks, :join_table => 'node_disks'
  has_many  :disks, :through => :node_disks
  
  # network ports
  has_many :network_switch_ports, :foreign_key => 'node_id'

  include CNU::IpManipulation

#  after_save :update_ip_on_mgmt_cluster

  def to_s
    self.to_label
  end

  def self.find_by_ip(ipaddr)
    search_str = "#{ipaddr.gsub("*", "%")}%"
    Node.find(:all, :conditions => ["mgmt_ip_address like :ip or HOST(cluster_nodes.ip_address) like :ip", {:ip => search_str}], :joins => :cluster_nodes)
  end

  def mgmt_ip_address_must_be_unique
      value = mgmt_ip_address
      if mgmt_ip_address.nil?
        return true
      end
       if ClusterNode.count(:conditions => 
                  ["host(ip_address) = ? and node_id <> ? ",ip(value), node_id]) > 0 then
          errors.add(:mgmt_ip_address, "must be a unique IP address per cluster") 
       elsif Node.count(:conditions => 
          ["host(mgmt_ip_address::inet) = ? and node_id <> ? ",ip(value), node_id]) > 0 then
          errors.add(:mgmt_ip_address, 'must be a unique IP address per node table') 
       end
    #   errors.add(:mgmt_ip_address, "must be unique") 
  end
  # pagination: per page count of nodes
  def self.per_page
    50
  end
  def self.find_by_fn_prefix(fn_prefix)
    find_by_name(fn_prefix.split('.')[0], fn_prefix.split('.')[1])
  end
  def self.find_by_name(hostname, location='nut')
    # loc = Location.find_by_datacenter(location) 
    dc = Datacenter.find_by_name(location)
    find_by_hostname_and_datacenter_id(hostname,dc.id)
  end
  def self.create_node_by_id(params) 
    dc = Datacenter.find(params[:datacenter_id])
    #
    aNode = create(params) #{:serial_no => serial_no, :node_type => nt, :hostname => name, :datacenter => dc ,:os_version => os_version }) 
    return aNode if aNode.id.nil?
    unless aNode.node_type.is_fan?
      mgmt_network = Network.datacenter_mgmt_network(dc) 
      aNode.mgmt_ip_address = mgmt_network.next_ip() 
      aNode.add_default_disk if aNode.node_type.is_virtual?
    end
    aNode
  end

  def self.create_node(serial_no, node_type, os_version, name, dc_id, mgmt_ip=nil) 
    nt = NodeType.find_by_name(node_type)
    raise NodeException.new('Unknown node type') if nt.nil?
    dc = Datacenter.find_by_name(dc_id)
    #
    mgmt_cluster = Cluster.find_mgmt_cluster_by_location(dc.name)
    aNode = create({:serial_no => serial_no, :node_type => nt, :hostname => name,
        :datacenter => dc ,:os_version => os_version }) 
    return aNode if aNode.id.nil?
    aNode.mgmt_ip_address = Cluster.add_node_to_cluster(mgmt_cluster, aNode, mgmt_ip)
    # mgmt_cluster.add_node(aNode, mgmtip)
    aNode
# FIXME: add options for these
#     Column      |  Type   |                        Modifiers                        
# model_id        | integer | 
# serial_console  | text    | 
# os_version_id   | integer | 
  end
  def self.find_all_active(*options) #, &block)
      active.all( *options )
  end
  def self.find_all_active_by_datacenter(dc, *options)
      active.find_all_by_datacenter_id(dc, *options )
  end
  def self.find_all_active_by_node_type(p_node_type, *options)
      active.find_all_by_node_type_id(p_node_type, *options )
  end
  def self.find_all_physical(&block)
      active.physical.all.select { |a| a.active? && (not a.eth0.nil?) }
  end
  def self.find_all_virtual(&block)
      active.all(:conditions => ['node_type_id = 2'])
  end
  def self.find_all_switches(dc=nil, &block)
      find_types(NodeType.find_by_name('switch'), dc)
  end
  def self.find_all_pdus(dc=nil, &block)
      find_types(NodeType.find_by_name('pdu'),dc)
  end
  def self.find_all_serial_consoles(dc=nil,&block)
      find_types(NodeType.serial_console,dc)
  end
  def self.find_all_load_balancers(dc=nil,&block)
      find_types(NodeType.load_balancer,dc)
  end
  private
  # base method for all find_*_<node_type> methods
  def self.find_types(ntype, datacenter=nil)
    raise NodeException.new("Invalid database setup") if ntype.nil?
    if datacenter.nil? then 
      find_all_by_node_type_id(ntype, :order => :hostname)
    else
      find_all_by_node_type_id_and_datacenter_id(ntype, datacenter, :order => :hostname)
    end
  end
  public
  # find my domO
  def xen_domO 
    return nil unless self.node_type and self.node_type.node_type == 'virtual' 
    return nil if self.xen_guest.nil?
    return self.xen_guest.host
  end
  # return the assigne equipment model or an approximately useful
  # valid CnuMachineModel object at all times.
  def machine
    if model.nil?
      if node_type.is_virtual?
        CnuMachineModel.new({:megabytes_memory => 4096, :cpu_cores => 2 })
      else
        CnuMachineModel.new({:megabytes_memory => 0, :cpu_cores => 0 })
      end
    else
      model
    end
  end
  # part of xen_capacity and resource mgmt.
  def percent_resources_used
      guests = self.xen_guests.map{|xm| m = xm.guest.machine; [m.ram, m.cpu_cores ]}.transpose.map{|c| c.sum }
      return [ 0, 0] if guests.empty?
      my_resources = [machine.ram,machine.cpu ]

     if my_resources.first == 0 or my_resources.last == 0 then
        return [ 0, 0] 
     end
  
#  => [17152, 23]
#>> [xen.model.ram, xen.model.cpu ]
#=> [32768, 8]
#>> (17152.to_f / 32768.to_f * 100) .to_i
#=> 52
#>> [ [17152, 23], [32768, 8]].transpose.map{|r| (r.first.to_f / r.last.to_f * 100).to_i }
    [ guests , my_resources ].transpose.map{|r| (r.first.to_f / r.last.to_f * 100).to_i }
  end

  # determine if a xen dom0 or not
  # TODO: fix this
  def is_xen_dom0?
    self.node_type and self.node_type.node_type == "physical" and self.xen_guests.length > 0
  end

  # calculate xen capacity for this domO
  def xen_capacity
    return nil unless self.is_xen_dom0? and !self.model.nil?

    cap = {}
    cap[:cpu_cap] = self.model.cpu_cores
    cap[:mem_cap] = self.model.megabytes_memory
    
    cap[:cpu_use] = 0
    cap[:mem_use] = 0

    self.xen_guests.each do |n|
      unless n.guest.model.nil?
        cap[:cpu_use] += n.guest.model.cpu_cores
        cap[:mem_use] += n.guest.model.megabytes_memory
      else
        cap[:cpu_use] += 2
        cap[:mem_use] += 4096
      end
    end

    cap
  end

  def mapping_table(nodes)
    nodes.map {|n| [ n.domo == self, n.live_domo == self ] }
  end

  private
  # add a nic card basic method to do type checking
  def add_nic(p_mac_addr, p_port_name, p_net_type)
    unless p_net_type == 'lan' or p_net_type == 'san' then
      raise Exception.new("Invalid network type: #{p_net_type}")
    end
    aNic = Nic.create({:mac_address => p_mac_addr, 
                :port_name => p_port_name, 
                :network_type =>p_net_type })
    self.nics << aNic
  end
  public
  # convience methods
  def add_lan_nic(p_mac, p_port_name )
    add_nic(p_mac, p_port_name, 'lan')
  end
  def add_san_nic(p_mac, p_port_name )
    add_nic(p_mac, p_port_name, 'san')
  end
  
  # magic method to setup Nics for xen domUs
  # based on the cluster assignments
  def create_virtual_nics()
    return 0 unless node_type.is_virtual?
#		nic_ref = nics.map {|nc| nc }
#		# remove references to nics
#		self.nics.clear
#		# iterate through old nics and destroy objects if they do not belong to any nodes
#		nic_ref.each { |nr| nr.destroy if nr.nodes.empty? }
    #return if nics.length == clusters.length
    vlans = clusters(true).map  {|c| c.vlan }
    if mgmt_ip_address then
      vlans << mgmt_ip_address.network.vlan
    end
    # TODO:
    #  add in check for direct attached networks
    nic_count = nics(true).length
    ports = []
    x = vlans.map{|vlan|
      iface = "#{net_type}#{vlan}" 
      ports << iface
      if nics.find_all_by_port_name(iface).empty? then
          add_lan_nic(Nic.mk_xen_mac, iface)
          nic_count = nic_count+ 1
      end
    }
    
    if nic_count != clusters.length then
      nics.each { |nic|
        unless ports.member? nic.port_name then
          # puts "needs to delete #{nic.port_name} on #{fn_prefix}" if nic.lan?
          nics.delete(nic) if nic.lan?
        end
      }
    end
    x.compact.length
  end
  # convience method
  def plug_into(pdu, outlet)
    Pdu.plug_node_into_pdu(self, pdu, outlet)
  end
  # fully qualified omain name 
  # TODO: make example.com a configurable value 
  def fqdn
    "#{to_label}.example.com"
  end
  # basic way to uniquely refer to a host here
  def fn_prefix
    #raise Exception.new('what the fuck') unless active?
    if active? then
      "#{hostname}.#{datacenter.name}"
    else
      hostname 
    end
  end
  # Rails method
  def to_label
    fn_prefix
  end
  # alias for serial_no. throws an exception as this method should
  # not be called on nodes with no serial_no
  def uuid
     return serial_no unless (serial_no.nil? or serial_no == '')
     raise Exception.new('no uuid for you')
  end
  # loop over nics to generate udev rules for node
  def nic_udev_rules
      nics.map {|nic| nic.udev_rule }
  end
  # is the node active? and able to function correctly in the system
  def active?
    (not node_type_id.nil?) && (node_type_id != 3) && ( (not datacenter_id.nil?) or (not location_id.nil?)  )
  end
  # policy constraint for an lb
  # load balancers need the correct type and one pdu
  def lb_active?
    self.active? and self.node_type.node_type == 'load balancer' and self.pdus.length == 1 
  end

  # 
  # mac_eth0, eth0,eth1: might be removable
  #
  # find first mac address 
  def mac_eth0
    eth0.mac_address
  end

  # find eth0 nic 
  def eth0
    nics.find_by_port_name('eth0')
  end
  # find eth1 nic 
  def eth1
    nics.find_by_port_name('eth1')
  end
  # list of lan nics
  def lan_nics
    x = nics.find_all_by_network_type('lan', :order =>:port_name)
    x = [] if x.nil?
    x
  end

  # SAN nic interface management
  def san_nics
    x = nics.find_all_by_network_type('san', :order =>:port_name)
    x = [] if x.nil?
    x
  end
  # list of san port names
  def san_network_ports
    if san_nics.length == sans.length 
      san_nics.map {|x| x.port_name }
    else
      []
    end
  end
  # create a list of all san interfaces
  # list of pairs port name and ip address
  def san_interfaces
    if san_nics.length == sans.length 
      ports = san_network_ports().sort
      ips = san_nodes.map{|x| x.ip_address.to_s }.sort
      #return [] if ports.length != ips.length 
      ports.zip(ips)
    else
      []
    end
  end
  # generate list of eths to san_paths
  def san_paths
     san_array_node = self.sans.first.san_array_node
     return [] if  san_array_node.nil?
     x = san_array_node.san_interfaces
     return [] if x.length < 1
     xx = x.enum_slice((x.length / 2)).to_a 
     # permitation of san controllers
     san_port_array =  xx.first.zip(xx.last).flatten(1)
     san_interfaces.map{|saniface| [saniface.first, 
            san_port_array[saniface.last.split('.').last.to_i % san_port_array.length].last] }
  end
  # combine san and lan network interfaces
  def network_interfaces
    sans = san_network_ports
    n = clusters.map{|x| x.vlan}.sort
    if has_mgmt? then
      n << 4000
    end
    app = n.map{|x| "vlan#{x}"}
    app.concat(sans)
  end
  # used in net_services to perform magic
  def mangle(netport)
      netport.sub(/\d+/,'4000')
  end
  # return eth for xen domUs vlan'd interfaces other wise call it vlan
  def net_type
    if node_type.name == 'virtual' then
       'eth'
    else
       'vlan'
    end
  end
  # create a list of lists of net.services rules for this node
  def net_services
    svc = []
#    svc =  cluster_configurations.map{ |cc| cc.net_service(self.node_type.node_type) }
    clusters.each do |cc| 
      cc.services.each {|s|
          svc << [s.ha_ip_address , s.ha_port ,
            s.ha_proto, s.localport,
           "#{net_type}#{cc.vlan}" # local interface
          ]
      }
      svc << [nil, nil,'icmp', nil, 
          "#{net_type}#{cc.vlan}" # local interface
        ]
    end
    #puts "DEBUG:#{hostname}: #{svc.inspect}" if is_load_balancer? 
    if is_server? then 
       svc2 = []
       svc.each { |s| 
          svc2 << ["","",s[2],s[3], mangle(s[4])]
          svc2 << ["","",s[2],s[3], s[4]]
       }
      #puts "DEBUG:#{hostname}: #{svc2.inspect}" if is_load_balancer? 
      svc.concat(svc2)
    end
    # will be wrong for virutal with SANs
    san = san_nics.map { |nic| [nil, nil, 'tcp', 22, nic.port_name] }
    svc.concat(san)
    if node_type.is_loadbalancer?
       ha_svc = ClusterConfiguration.find_all_ha_net_services
       svc.concat(ha_svc)
       # For Testing only - Delete after Feb 28, 2009 or come up with
       # something better
       test_vlans = Cluster.find(:all, :conditions => ["vlan <= 102 and vlan > 8"]).map{|c| c.vlan }
       testing_svc = test_vlans.map{|vlan|
                            [nil,nil,'tcp',22, "vlan#{vlan}"]
                      }.uniq
       svc.concat(testing_svc)
       testing_svc = test_vlans.map{|vlan|
                            [nil,nil,'icmp',nil, "vlan#{vlan}"]
                      }.uniq
       svc.concat(testing_svc)
    end
    # Icmp for application vlans
    if node_type.is_virtual?
      icmp = nics.map { |nic| 
         [nil,nil,'icmp',nil, nic.port_name]  if nic.port_name =~ /eth\d+/ 
      }.compact
      svc.concat(icmp)
      nginx = nics.map { |nic| 
         [nil,nil,'tcp', 80, nic.port_name]  if nic.lan? and nic.port_name =~ /eth\d+/ 
      }.compact
      svc.concat(nginx)
    end
    if hostname == 'uk01' then
      svc << [nil,nil,'tcp',11301,'eth4000']
    end
    rules = svc.map{|a| a.join(':') }
    if mgmt_ip_address then
      rules.concat( mgmt_ip_address.network.net_service(net_type) )
    end
    rules.map{|a| %Q(\t"#{a}") }.sort.uniq.join("\n")
  end
  
  
  #DEPRECATED: to be replaced with node_type.can_has support.
  def is_load_balancer?
    node_type.is_loadbalancer?
  end
  #DEPRECATED
  def is_server? 
      node_type.is_node? 
  end
  # create a new node in another colo to be this nodes supernode
  def clone_node(dc_name)
    # only clone virtual nodes
    return nil unless node_type.is_virtual?
    # can't clone to yourself. redendent below but less work
    dc = Datacenter.find_by_name(dc_name)
    return nil if dc.name == datacenter.name
    # can't clone an existing node. 
    x = Node.find_by_name(hostname, dc.name)
    return x unless x.nil?
    mgmt_cluster = Cluster.find_mgmt_cluster_by_location(dc.name)
    # clone me!
    aNode = clone()
    aNode.datacenter = dc
    aNode.mgmt_ip_address = nil 
    aNode.save
    aNode.mgmt_ip_address = Cluster.add_node_to_cluster(mgmt_cluster, aNode)
    aNode.save
    # clone nics
    nics.each{|n| 
      aNode.nics  << n
    }
    # clone all non-mgmt clusters
    cluster_nodes.each {|cn|
      if cn.cluster.vlan != 4000 then
        ClusterNode.create({:cluster_id => cn.cluster_id, :node_id => aNode.id, :ip_address => cn.ip_address })
      end
    }
    aNode
  end
  # sync a node in another colo to be self's paired super node
  def pairup(other_node)
    if other_node.clusters.length > 1 then
      puts "Can't pair #{other_node.fn_prefix} has other clusters"
      return false
    end
    
    # match nics
    if self.node_type.is_virtual? and other_node.node_type.is_virtual? then
      unless self.nics == other_node.nics 
        other_node.nics.clear 
        self.nics.each {|nic|
          other_node.nics << nic
        }
      end
    end
    # match cluster
    # TODO: loop over other_node.clusters and remove all non-mgmt clusters
    self.clusters.each {|c|
      next if c.cluster_name =~ /mgmt/
      c.add_node(other_node,c.ip_address)
    }
    # match OS
    other_node.os_version_id = self.os_version_id
    # match OS
    other_node.model_id = self.model_id 
    other_node.save
  end
  # determine if this node be deleted
	def is_removable?
		self.clusters.empty? and self.network_switch_ports.empty? and self.pdus.empty? and self.sans.empty? and self.serial_consoles.empty?
	end

  # clear out join table and objects related to nodes
  def clear_node_association(join_list)
    # array of node's nics to use later
    refs = join_list.map {|n| n }
    # remove references to nics
    join_list.clear
    # iterate through old nics and destroy objects if they do not belong to any nodes
    refs.each { |r| r.destroy if r.nodes.empty? }
  end

	def remove
		# raise exceptions if part of cluster/network/san/pdu/serial/network port
		unless is_removable?		
			raise Exception.new('Can not remove.')
		end
    
    clear_node_association nics if not nics.empty?
    clear_node_association disks if not disks.empty?    

		# if the node is virtual and has a xen mapping, destroy the xen mapping
		if self.node_type.is_virtual?
      unless self.live_xen_host.nil?
        l_xen_map = self.live_xen_host
        l_xen_map.domu = nil
        l_xen_map.client_id = nil
        l_xen_map.save!
      end
			XenMapping.remove_guest(self) unless self.xen_guest.nil?
		end
		# destroy
		self.destroy
	end
  
  # search Node table
  def self.search_by_hostname(q)
    search_by_column(:hostname, q) 
  end
  def self.search_by_column(column, term)
    where_clause  = %Q("#{column.to_s}" like ?) 
    search_term = term.gsub('*','%')
    if search_term.index("%").nil? and search_term.index("_").nil? then
      search_term = search_term.concat("%")
    end
    Node.find(:all, :conditions => [where_clause, search_term] )
  end

  #  find the list of all vlans needed by the domUs for this domO
  def vlans
    if self.node_type.is_physical?
      vlan_list = self.clusters.map { |c| c.vlan }
      unless self.xen_guests.empty?
        vlan_list << self.xen_guests.map { |n| n.guest.clusters.map { |c| c.vlan } }
      end
      vlan_list.flatten.uniq
    end
  end

  # disks
  def add_default_disk
    default_disk = Disk.create_xen_disk("disk.img", "/", 4096)
    disks << default_disk
    if only_supports_ide?
      default_disk.assign_block_name(self, "hda1")
    else
      default_disk.assign_block_name(self, "sda1")
    end
  end

  def next_disk_block(disk_type)
    disk = self.get_last_disk disk_type
    if disk.blank?
      if self.node_type.is_virtual?
        # when a disk is added to a virtual node with no disks, an "sda1" default disk is auto-created
        block = disk_type == DiskType.file ? "sda2" : "sdb"
      else
        if disk_type == DiskType.file
          last_iscsi_disk = get_last_disk DiskType.iscsi
          block = last_iscsi_disk.nil? ? "sda1" : next_device_disk(last_iscsi_disk)
        else
          last_file_disk = get_last_disk DiskType.file
          block = last_file_disk.nil? ? "sda" : next_device_disk(last_file_disk)
        end
      end
    elsif disk.block_name(self).blank?
      if disk_type == DiskType.file
        block = "sda1"
      else
        block = "sda"
      end
    else
      block = disk.block_name(self).to_s
    end

    # conflicting_disks = self.disks.select{|d| d.block_name == block}
    while self.disks.detect{|d| d.block_name(self) == block}
      raise Exception.new("Invalid block name!") if not block =~ /\A(?:s|h)d([a-z]+)\d*\Z/
      prefix = Disk.block_prefix(block)
      chars = Disk.block_chars(block)
      digits = Disk.block_digits(block)
      
      if disk_type == DiskType.file and self.disks.detect{|d| d.disk_type == DiskType.file}
        # prevent using a partition number block when a non-file type disk already occupies the base block
        # eg don't assign "sda1" to a file disk when there's an iscsi named "sda"
        block = next_partition(prefix, chars, digits)
      else
        block = next_device(prefix, chars)
      end
    end
    return block
  end
  # return the disk with the "maximal" block name. ie: max[sda15, sdb, sdb3] == sdb3
  def get_last_disk(disk_type)
    node_disks = self.node_disks.select{|nd| nd.disk.disk_type == disk_type}
    return node_disks.max.disk if not node_disks.blank?
    nil
  end

  # Xen HVM Windows instances only support IDE drives (hd... block names) (08/24/2010)
  def only_supports_ide?
    if node_type.is_virtual? and os_version and os_version.hvm_only?
      true
    else
      false
    end
  end

  private
  def next_device_disk(disk)
    block = disk.block_name(self)
    raise Exception.new("Invalid block name!") if not block =~ /\A(?:s|h)d([a-z]+)\d*\Z/
    prefix = Disk.block_prefix(block)
    chars = Disk.block_chars(block)
    next_device(prefix, chars)
  end
  def next_partition(prefix, chars, digits)
    if not digits.blank?
      if digits.to_i < 15
        prefix + chars + digits.next
      elsif digits.to_i == 15
        next_device(prefix, chars)
      else
        raise "Invalid block name!"
      end
    else
      prefix + chars + "1"
    end
  end
  def next_device(prefix, chars)
    if chars == "dx"
      raise "Already at largest block name!"
    else
      prefix + chars.next
    end
  end

  # 
  # change the node's mgmt_ip_address column as well as the
  # ClusterNode.ipaddress column for the mgmt network forthis node.
  def update_ip_on_mgmt_cluster
    if mgmt_ip_address_changed?
      mgmt_cluster = Cluster.find_mgmt_cluster_by_location(datacenter.name)
      return true if mgmt_cluster.blank?
      cluster_node = cluster_nodes.detect{|cn| cn.cluster == mgmt_cluster}
      return true if cluster_node.blank?
      cluster_node.change_ip(mgmt_ip_address)
    end
    return true
  end
  def has_mgmt?
    !(mgmt_ip_address.nil?)
  end

  public
  # FIXME make iqn prefix to be configurable per installation
  def iqn
    "iqn.2010-09.com.example:01:#{datacenter.name}.#{hostname}"
  end

end


class San < ActiveRecord::Base
  set_primary_key 'san_id'
  has_paper_trail
  has_and_belongs_to_many :nodes, :join_table => 'san_nodes'
  has_many :san_nodes
  belongs_to :network

  before_validation :clear_empty_attrs

  validates_presence_of  :network_id
  validates_presence_of  :name
  validates_presence_of  :description
  validates_length_of :san_name, :within  => 2..32
  validates_format_of :san_name, :with => /\A[^ \t]+\Z/, :message => "has spaces"
  validates_length_of :description , :minimum => 5
  validates_uniqueness_of :san_name
  attr_accessor :kind
  
  def san_array_node
     x = self.connection.select_one(
        "select distinct node_id from sans join
            san_nodes using (san_id) join nodes using (node_id) join node_type using (node_type_id)  
        where node_type = 'san' and san_id = #{self.id}")
     if x.nil?  then
        nil
     else
        Node.find(x["node_id"])
     end
  end
  def is_3par?
    self.kind == '3par'
  end
  def is_equallogic?
    self.kind == 'equallogic'
  end 
  def conn_info
    if self.is_3par?
      '10.80.0.101'
    elsif self.is_equallogic?
      'localhost'
    else
      raise Exception.new('Bad San type for SanNode!')
    end
  end

  def self.available_networks
     Network.san
  end
  def ip_range
    network.ip_range
  end
  def vlan 
    network.vlan
  end
  def magic_datacenter
    dc = Datacenter.find(:all)
    dc.each { |d| return d if self.name.downcase.include? d.name }
    nil
  end

  def name
    san_name
  end
  def to_label
    san_name
  end

  def empty_interfaces(node)
      n_used_ports = SanNode.find_all_by_node_id(node).length 
      total_ports = node.san_nics.length
      total_ports - n_used_ports
  end
#      if node_ip.length > 0 and node_ip.length > node.san_nics.length then
#        msg = "Node has #{node.san_nics.length} SAN nic ports but pass in " +
#        "#{node_ip.length} assignned addresses" 
#        raise SanException.new(msg)
#      end

  #  add_node(node, array of IP address to SAN.
  #  We generate a new SanNode association for each exisitng nic
  #  on the node marked as a 'san'
  #  Allow ips to be assigned by passing in an array of IPs
  #  We assign IP addresses for each san nic.
  #  Can be called on a node with assigned SAN ips as it will
  #  only assign new IPs for those nic which don't have an IP
  def add_node(node, node_ip=[])
      unless node.class == Node and node_ip.class == Array then
        raise SanException.new('error: add_node(node, node_ip=[])')
      end
      # TODO add location check
      Range.new(1, empty_interfaces(node) ).map do |n| 
       ip =  if node_ip.empty?
                next_node_ip() 
             else
                node_ip.shift
             end
        SanNode.create({:san_id => san_id, :node_id => node.id, :ip_address_id => ip.id})
      end 
  end

  def remove_node(node)
      unless node.class == Node then
        raise SanException.new('error: remove_node(node)')
      end
      x = SanNode.find_all_by_san_id_and_node_id(self, node)
      ips = x.map {|y| y.ip_address }
      self.nodes.delete(node)
      ips.each {|y| y.destroy() }
# this code doesn't work as SanNode has no single column primary key
# but this is the code that is needed to properly delete ip_address links
#      # x.map{|sn| sn.delete }
  end
  private 
  def next_node_ip
    network.next_ip() # connection.select_value("select cnu_net.san_next_ip_address(#{san_id})")
#create or replace function san_next_ip_address(san cnu_net.sans.san_id%TYPE)
#returns inet
#DECLARE
#  last_ip cnu_net.san_nodes.ip_address%TYPE;
#  san_ip_range cnu_net.sans.ip_range%TYPE;
#BEGIN
#  select into san_ip_range ip_range from sans where san_id = san;
#  select into last_ip ip_address from san_nodes where san_id = san order by ip_address desc limit 1;
#  last_ip := coalesce(last_ip, inet(san_ip_range)+10);
#  if broadcast(last_ip) <= last_ip + 1 then
#    raise exception 'No more addresses in san: %', san;
#  end if;
#  raise notice 'New IP: % for san %', last_ip+1, san;
#  return last_ip + 1;
#END;
#     x =  select(%Q(select '#{prefix}.0'::inet + s as ip_address 
#            from generate_series(20,254,1) as s(a) except 
#            select distinct ip_address::inet 
#            from services where ip_address like '#{prefix}.%' ))
  end
end
class SanNode < ActiveRecord::Base
  before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail
  belongs_to :node
  belongs_to :san
  belongs_to :ip_address
  def to_label
    "#{self.san.to_label} - #{self.node.to_label}: #{self.ip_address.to_label}"
  end
end
class NodeType < ActiveRecord::Base
  set_primary_key 'node_type_id'
  set_table_name 'node_type'

  has_paper_trail

  acts_as_static_record

  has_many :nodes
  
  def self.find_by_name(*args)
     find_by_node_type(args)
  end
  def self.serial_console
    find_by_name('serial console')
  end 
  def self.load_balancer
    find_by_name('load balancer')
  end 
  def name  
    node_type
  end  
  def can_has_pdu?
    is_physical? or is_loadbalancer? or is_switch? or is_san? or is_serial_console? or is_sensor? \
      or is_router? or is_fan?
  end
  def can_has_switch_port?
    is_physical? or is_loadbalancer? or is_san? or is_serial_console? \
      or is_sensor? or is_pdu? or is_switch? or is_router?
  end
  def can_has_disk?
    is_node? or is_loadbalancer?
  end
  def can_has_serial_console?
    is_physical? or is_loadbalancer? or is_san? or is_serial_console? \
    or is_switch? or is_pdu?  or is_router?
  end
  def can_has_net_service?
    is_node? or is_loadbalancer?
  end
  def is_switch?
    node_type == 'switch'
  end
  def is_loadbalancer?
    node_type == "load balancer"
  end
  def is_pdu?
    node_type == 'pdu'
  end
  def is_node?
    ['physical','virtual'].member? node_type
  end
  def is_physical?
    node_type == 'physical'
  end
  def is_san?
    node_type == 'san'
  end
  def is_serial_console?
    node_type == "serial console"
  end
  def is_sensor?
    node_type == "sensor"
  end
  def is_fan?
    node_type == 'fan'
  end
  def is_virtual?
    node_type == "virtual"
  end
  def is_router?
    node_type == "router"
  end
  def can_has_sshd?
    is_node? or is_loadbalancer? or is_serial_console? or is_switch? or is_pdu? 
  end
end

class Protocol < ActiveRecord::Base
  set_primary_key 'protocol_id'
  has_paper_trail
  acts_as_static_record
  has_many :services
  def name
    proto.strip
  end
end

require 'uri'
class Service < ActiveRecord::Base
  set_primary_key 'service_id'
  has_paper_trail

  belongs_to :protocol
  has_many :cluster_services
  has_many :clusters, :through => :cluster_services

  has_many :depends_on_relationships, :foreign_key => 'parent_id', :class_name => 'ServiceDependency'
  has_many :required_by_relationships, :foreign_key => 'child_id', :class_name => 'ServiceDependency'

  has_many :depends_on, :through => :depends_on_relationships, :class_name => 'Service', :source => "child"
  has_many :required_by, :through => :required_by_relationships, :class_name => 'Service', :source => "parent"

  named_scope :addable, :conditions => ["ip_address is not null"], :order => :name


  validates_inclusion_of :availability , :in => %w(public campus),  :message => "{{value}} is not 'public' or 'campus'" 
  validates_presence_of :name 
  # validates_uniqueness_of :name, :case_sensitive => false
  validates_presence_of :url
  validates_presence_of :service_port
  validates_numericality_of :service_port, :only_integer => true, :message => "is not an integer" 
  validates_numericality_of :service_port, :greater_than => 0, :message => "is not greater than 0" 
  validates_numericality_of :service_port, :less_than => 65536, :message => "is not less than or equal to 65535" 
  validates_numericality_of :local_port, :only_integer => true, :message => "is not an integer" , :allow_nil => true
  validates_numericality_of :local_port, :greater_than => 0, :message => "is not greater than 0" , :allow_nil => true
  validates_numericality_of :local_port, :less_than => 65536, :message => "is not less than or equal to 65535", :allow_nil => true
# make sure check_url is not a full path like http://foo.bar/ping
  validates_format_of :check_url, :with => /\A(.(?!(:\/\/)))*\Z/, :allow_nil => true, :allow_blank => true

  validate :service_local_ports_not_equal 
  def service_local_ports_not_equal 
      errors.add_to_base("Service port can not equal Local port") if service_port == local_port
  end


  def ha_ip_address
    ip_address
  end
  def ha_port
    service_port
  end
  def ha_proto
    protocol.proto.strip
  end
  def ha_hostname
    return nil if self.url.nil?
    URI.parse(self.url).host
  end
  def ha_protocol 
    return nil if self.url.nil?
    URI.parse(self.url).scheme
  end
  def ssl?
    ['https','ldaps'].member? ha_protocol
  end
  def localport
    if local_port.nil?
      service_port 
    else
      local_port
    end
  end
  def to_s
    "#{name} - #{ha_proto}/#{ha_port} - #{local_port} - #{ha_protocol}"
  end
  def to_label
    "#{name} - #{ha_protocol}://#{ha_ip_address}:#{ha_proto}/#{ha_port} - #{local_port}"
  end

  def check_url_path
    return check_url unless check_url.nil?
    case name
    when /portal/ then '/ping'
    when /fe/ then '/ping'
    when /leads/ then '/ping'
    # add more options for non http services
    else '/'
    end
  end
 
  def has_downpage?()
    ['https','http'].member? ha_protocol and not_unique == 1
  end
  def active?
    not clusters.empty? 
  end

  def self.create_service(svc)
    # svc[:ip_address] 
    existing = find_by_name(svc[:name])
    if existing.nil? then 
      svc[:ip_address] = next_ip_address_by_availability(svc[:availability])
    else
      svc[:ip_address] = existing.ip_address
      svc[:availability] = existing.availability
      svc[:protocol_id] = existing.protocol_id
    end
    if svc[:local_port] == svc[:service_port] then 
      svc[:local_port] = nil
    end
    begin
      create(svc)
    rescue ActiveRecord::StatementInvalid
      new(svc)
    end
  end
  def self.find_ha_ip_services(ip_prefix)
    find(:all, :conditions => ["ip_address like '#{ip_prefix}.%%'"])
  end
  def self.public_services
    format_services(find_ha_ip_services('209.60.186'))
  end
  def self.public_services_used
    format_services(find_ha_ip_services('209.60.186').map{ |s| s if s.clusters.length > 0}.compact)
  end
  def self.private_services
    format_services(find_ha_ip_services('10.10.10'))
  end
  def self.private_services_used
    format_services(find_ha_ip_services('10.10.10').map{ |s| s if s.clusters.length > 0}.compact)
  end
  def self.format_services(svc)
    group_by = Hash.new([])
    svc.each do |s|
      a = group_by[s.ip_address].clone
      a << s
      group_by[s.ip_address ] = a.clone
    end
    formatted = group_by.map { |k,v|
        ports = []
        proto = []
        hosts = []
        name = []
        desc = []
        for i in v do
          ports << "#{i.ha_port}/#{i.ha_proto}"
          proto << i.ha_protocol unless i.ha_protocol.nil?
          hosts << i.ha_hostname unless i.ha_hostname.nil?
          desc << i.description unless i.description.nil?
          name << i.name unless i.name.nil?
        end
        [ name.uniq, k, hosts.uniq, ports.uniq, proto.uniq, desc.uniq] 
    }
    formatted
  end
private
  def self.next_ip(prefix)
    query  =  %Q[SELECT '#{prefix}.0'::inet + s as ip_address 
            FROM generate_series(20,254,1) as s(a) 
            EXCEPT (SELECT ip_address::inet 
            FROM services where ip_address like '#{prefix}.%'
            GROUP BY 1 ORDER BY services.ip_address::inet) limit 1]
    s = find_by_sql(query).first
    if s.nil? then
      raise ActiveRecord::RecordNotFound.new("No more IP address in network #{prefix}/24")
    else
      s.ip_address
    end
  end
  def self.next_ip_address_by_availability(avail)
     case avail
     when 'public'
        Service.next_public_ip_address
     when 'campus'
        Service.next_campus_ip_address
     end
  end
public
  def self.next_public_ip_address
    ip = self.next_ip('209.60.186')
  end
  def self.next_campus_ip_address 
    self.next_ip('10.10.10')
  end
end

class ServiceDependency < ActiveRecord::Base
  #before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail

  belongs_to :parent, :foreign_key => 'parent_id', :class_name => 'Service'
  belongs_to :child, :foreign_key => 'child_id', :class_name => 'Service'

end

class Distribution < ActiveRecord::Base
  has_paper_trail

  has_many :os_versions, { :foreign_key => "distribution", :primary_key => "name" }

  validates_uniqueness_of :name, :case_sensitive => false
end

class OsVersion < ActiveRecord::Base
  has_many :nodes
  has_paper_trail

  validates_presence_of :distribution
  validates_presence_of :kernel

  def name
    "#{distribution}(#{kernel})"
  end
  def to_label
    name
  end
  def hvm_only?
    if distribution =~ /windows/i
      true
    else
      false
    end
  end

end

class Location < ActiveRecord::Base
  set_primary_key 'location_id'
  has_paper_trail
  belongs_to :datacenter
  has_many :nodes
#        => ["location_id", "datacenter_id", "rack", "rack_position_bottom", "rack_position_top"]
  def self.find_by_datacenter(dc_name)
    dc = Datacenter.find_by_name(dc_name.downcase)
    raise ActiveRecord::RecordNotFound.new("No Datacenter named #{dc_name}") if dc.nil?
    find(:first, :conditions => ["datacenter_id = ? and rack is null", dc.datacenter_id])
  end
end
class Datacenter < ActiveRecord::Base
  set_primary_key 'datacenter_id'
  has_paper_trail
  acts_as_static_record
  has_many :locations
  has_many :nodes 
  def self.nut
    Datacenter.find_by_name('nut')
  end
  def self.obr
    Datacenter.find_by_name('obr')
  end
  def to_label
    "Datacenter(#{name})"
  end
end


class XenMapping < ActiveRecord::Base
 # before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail
  belongs_to :host, :foreign_key => 'host_id', :class_name => 'Node'
  belongs_to :guest, :foreign_key => 'guest_id', :class_name => 'Node'
#-- test
#-- 
#-- select is_host(11), is_guest(11), is_host(28), is_guest(28);
#--  is_host | is_guest | is_host | is_guest 
#-- ---------+----------+---------+----------
#--  t       | f        | f       | t
  def self.assert_is_guest(node)
    return if node.node_type.is_virtual? 
    raise Exception.new("Not a guest #{node.fn_prefix}")
  end
  def self.assert_is_host(node)
    return if node.node_type.is_physical?
    raise Exception.new("Not a host #{node.fn_prefix}")
  end
  def self.move_guest(host, guest)
    assert_is_guest(guest)
    assert_is_host(host)
    XenMapping.remove_guest(guest) 
    return XenMapping.add_guest(host, guest) ;
  end
  ##########################################################3 
  def self.add_guest(host,guest)
    assert_is_guest(guest)
    assert_is_host(host)
    XenMapping.create({:host_id => host.id, :guest_id => guest.id})
  end
  def self.remove_guest(guest)
    assert_is_guest(guest)  
    x = XenMapping.find_by_guest_id(guest.id)
    return true if x.nil?
    x.destroy()
    true
  end
  def self.unassigned(*options)
      Node.find_by_sql("select * from nodes left outer join xen_mappings on node_id = guest_id 
                      join node_type using (node_type_id) where node_type = 'virtual' and guest_id is null
                      order by hostname")
  end
  def self.check_mapping(maps)
     maps.each {|x,n| 
      c = XenMapping.count(:conditions => ["guest_id = ? and host_id = ?", 
            Node.find_by_name(*n.split('.')), Node.find_by_name(*x.split('.'))])
      if c != 0 then
        nil
      else
        [x,n]
      end
    }
  end

  def self.get_live_mappings
    require 'yaml'

    datacenters = Datacenter.find(:all).map { |d| d.name }

    mappings = {}
    
    datacenters.each do |dc|
      begin
        tmp = YAML.load_file("#{RAILS_ROOT}/tmp/xen_status.#{dc}")
        mappings.merge!(tmp)
      rescue Exception => e
        next
      end

    end

    mappings
  end
end

class Pdu < ActiveRecord::Base
 # before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail
  #has_and_belongs_to_many :powersink, :foreign_key => 'node_id', :class_name => 'Node'
  belongs_to :powersink, :foreign_key => 'node_id', :class_name => 'Node'
  belongs_to :node, :foreign_key => 'node_id', :class_name => 'Node'
  belongs_to :pdu, :foreign_key => 'pdu_id', :class_name => 'Node'
  validates_uniqueness_of :pdu_id, :scope => [:pdu_id, :outlet_no]

  def self.plug_node_into_pdu(p_node, p_pdu, p_outlet)
    unless p_pdu.node_type.is_pdu? and ( not p_node.node_type.is_pdu?) then 
    raise Exception.new("Failed pdu #{p_pdu.node_type.is_pdu?} and node not #{p_node.node_type.is_pdu?}")
    end
    Pdu.create({:pdu_id => p_pdu.id, :node_id => p_node.id, :outlet_no => p_outlet})
  end
end

#def last_octet(i)
#ip(i).split('.')[-2] + '.' +  ip(i).split('.')[-1]
#end
#
#def reverse_ip(ip)
#  ip.split('.').reverse.join('.')
#end
#
# ex: mac = MacAddr.new("00:21:9b:a6:19:85"). You can then sort mac with other MacAddrs
class MacAddr
  attr_accessor :mac

  def initialize(mac)
    @mac = mac.to_s
  end
  def to_s
    @mac
  end
  def <=>(other)
    macs = @mac.split(':')
    others = other.to_s.split(':')
    macs.each_with_index{|num, index|
      comparison = (num.to_i(16) <=> others[index].to_i(16))
      return comparison if comparison != 0
    }
    return 0
  end
  include Comparable
end

class Loadbalancers

  def self.load_balanced_vlans
    Node.find_all_load_balancers.map{|n| n.clusters.map{|c| c.vlan}}.flatten.uniq
  end

def self.count
    cnt = 0 
    nt = NodeType.find_by_name('load balancer')
    Node.find_all_by_node_type_id(nt).each { |node|
       cnt = cnt + 1 if  node.lb_active?  
    }
   cnt
   3  # FIXME: set to three for duration of latisys spin up
end 

def self.find_all 
    lb = []
    nt = NodeType.find_by_name('load balancer')
    lb = Node.find_all_by_node_type_id(nt).map  { |node|
        if node.lb_active?  then
          node 
        else
           nil
        end
    }
    lb.compact!
    lb
end 
################
end


#
#Table "cnu_net.cnu_machine_models"
#       Column        |  Type   |
# megabytes_memory    | integer | 
# power_supplies      | integer | 
# cpu_cores           | integer | 
# cpu_speed_megahertz | integer | 
# network_interfaces  | integer | 
# model_no            | text    | 
# manufacturer        | text    | 
# max_amps_used       | integer | 
### max_btu_per_hour    | integer | 
# serial_console_type | text    | 
# rack_size           | integer | 
class CnuMachineModel < ActiveRecord::Base
  set_primary_key 'model_id'
  has_paper_trail
  has_many :nodes
  # validates_inclusion_of :availability , :in => %w(public campus),  :message => "{{value}} is not 'public' or 'campus'"
  validates_presence_of :manufacturer
  validates_presence_of :model_no

  def to_label 
    if cpu_cores.nil? or ram.nil? then
    "#{manufacturer}: #{model_no}"
    else
    machine_description
    end
  end
   
  def description
    to_label
  end
  def machine_description
    "#{model_no}: #{cpu_cores} CPU#{cpu_cores > 1? 's': ''}, #{self.ram} megs"
  end
  def ram 
    self.megabytes_memory    
  end
  def cpu
    self.cpu_cores
  end
  def xserial_dce_dte=(x)
   xx = case x
    when true
      true
    when /dce/i then
      true
    when false
      false
    when nil
      false
    when /dte/i
      false
    else
      nil
    end
    return nil if xx.nil?
    
    if xx then
      self[:serial_dce_dte] = true
    else
      self[:serial_dce_dte] = false
    end
  end
  def serial_dce_dte
    if read_attribute(:serial_dce_dte) then
      'dce'
    else
      'dte'
    end
  end
#  def serial_flow_control
#    table_serial_flow_control = read_attribute(:serial_flow_control)
#    if table_serial_flow_control.nil? then
#      'none'
#    elsif table_serial_flow_control then
#      'hardware'
#    else
#      'software'
#    end
#  end
  def serial_console
    return nil if serial_baud_rate.nil?
    [serial_baud_rate, serial_dce_dte, serial_flow_control]
  end
end

class Disk < ActiveRecord::Base
  set_primary_key 'disk_id'
  has_paper_trail
  has_many :node_disks
  # has_and_belongs_to_many :nodes, :join_table => 'node_disks'
  has_many :nodes, :through => :node_disks
  #belongs_to :node, :join_table => 'node_disks'
  validates_presence_of :name
  # validates_uniqueness_of :block_name, :scope => :nodes, :allow_nil => true, :case_sensitive => false
  # TODO: make sure block name is not null and unique per node once disks on physical machines gets figured out
  # validates_presence_of :block_name
  #validates_presence_of :devicename
  
  validates_numericality_of :total_megabytes, :only_integer => true

#  phy:/dev/iscsi-targets/iqn.2001-05.com.equallogic:0-8a0906-797ea7201-13c000db50647222-jabber-part1,sda1,w                 | iscsi
#      10 |    | /usr/share   | f      | file:/xen/domains/ukbwa/disk-usr.img,sda3,w | file
#       9 |    | /            | f      | file:/xen/domains/ukbwa/disk.img,sda1,w     | file
#
#
 #phy:/dev/iscsi-targets/iqn.2001-05.com.equallogic:0-8a0906-797ea7201-13c000db50647222-jabber-part1,sda1,w | iscsi
 #      10 |    | /usr/share   | f      | file:/xen/domains/ukbwa/disk-usr.img,sda3,w | file
 #       9 |    | /            | f      | file:/xen/domains/ukbwa/disk.img,sda1,w     | file
 #
 #
 #
 # phy:/dev/iscsi-targets/iqn.2001-05.com.equallogic:0-8a0906-797ea7201-13c000db50647222-jabber-part1,sda1,w
 # phy:/dev/iscsi-targets/iqn.2001-05.com.equallogic:0-8a0906-f1e023602-a59fa1797234b986-blog-web,sda1,w
  def iscsi?
    disk_type == DiskType.iscsi
  end
  def file?
    disk_type == DiskType.file
  end
  def xen_mode
    if read_only?
      'r'
    else
      'w'
    end
  end
  def self.create_xen_disk(volume, mount="/data", size=1)
    create({:total_megabytes => size, :mount_point => mount, :name =>volume, :disk_type => "file"})
  end
  def self.create_iscsi(volume, mount="/data",size=1)
    create({:total_megabytes => size, :mount_point => mount, :name =>volume, :disk_type => "iscsi"})
  end
  def block_name(node)
    node_disk = node_disks.detect{|nd| nd.node == node}
    node_disk.block_name if not node_disk.blank?
  end
  def assign_block_name(node, block)
    node_disk = node_disks.detect{|nd| nd.node == node}
    unless node_disk.blank?
      node_disk.block_name = block
      node_disk.save
    end 
  end
  def can_be_removed_from?(node)
    true unless node.node_type.is_virtual? and not (node.disks - [self]).detect{|d| d.mount_point == '/'}
  end
  
  private
  def self.block_prefix(block)
    return block.scan(/\A[a-z]d/).first
  end
  def self.block_chars(block)
    return block.match(/\A[a-z]d([a-z]+)/)[1]
  end
  def self.block_digits(block)
    return block.scan(/\d+/).first
  end 
  public
end

class NodeDisk < ActiveRecord::Base
  include Comparable
  has_paper_trail
  belongs_to :disk
  belongs_to :node

  validates_uniqueness_of :block_name, :scope => :node_id, :allow_nil => true

  def xen_name
    # TODO: Switch to throwing an error in gen_domU once 'h' block names for HVM guests are enforced
    if disk.file? then
      if node.only_supports_ide?
        "file:/xen/domains/#{node.hostname}/#{disk.name},#{'h'+block_name.last(block_name.length - 1)},#{disk.xen_mode}"
      else
        "file:/xen/domains/#{node.hostname}/#{disk.name},#{block_name},#{disk.xen_mode}"
      end
    elsif disk.iscsi? then
      if node.only_supports_ide?
        "phy:/dev/iscsi-targets/#{disk.name},#{'h'+block_name.last(block_name.length - 1)},#{disk.xen_mode}"
      else
        "phy:/dev/iscsi-targets/#{disk.name},#{block_name},#{disk.xen_mode}"
      end
    else
      name
    end
  end

  def <=>(other_node_disk)
    blk = self.block_name.to_s
    other_blk = other_node_disk.block_name.to_s

    # to account for the fact that the block name might be nil. Remove once not null
    # constraint has been placed.
    if blk == other_blk or blk == "" or other_blk == ""
      blk <=> other_blk
    else
      prefix = Disk.block_prefix(blk)
      other_prefix = Disk.block_prefix(other_blk)
      chars = Disk.block_chars(blk)
      other_chars = Disk.block_chars(other_blk)
      digits = Disk.block_digits(blk)
      other_digits = Disk.block_digits(other_blk)
      
      if prefix == other_prefix
        if chars == other_chars
          digits.to_i <=> other_digits.to_i
        else
          if chars.length == other_chars.length
            chars <=> other_chars
          else
            chars.length <=> other_chars.length
          end
        end
      else
        prefix <=> other_prefix
      end
    end
  end
end

class DiskType < ActiveRecord::Base
#    <%= collection_select(:disk, :disk_type, DiskType.all, :id, :disk_type) %>
  has_paper_trail

   def self.file
      find_by_disk_type('file').disk_type
   end
   def self.iscsi
      find_by_disk_type('iscsi').disk_type
   end
   def self.direct
      find_by_disk_type('direct').disk_type
   end
end

# TODO:
# modify table to add description field. allow node_id to be null IF a
# description exists.
class NetworkSwitchPort < ActiveRecord::Base
  has_paper_trail
  belongs_to :switch, :foreign_key => 'switch_id', :class_name => 'Node'
  belongs_to :node, :foreign_key => 'node_id', :class_name => 'Node'

  validates_presence_of :node_id, :switch_id, :port
  validates_format_of :port, :with => /^[A-La-l]\d\d?$/,
              :message => "Wrong Port for HP Switches modules [A-L][0-9][0-9]"
  validate :switch_is_a_switch, :not_plugging_into_self, :same_location
  
  def not_plugging_into_self 
    errors.add(:node_id, "can't be plugged into self") if switch == node
  end 
  def switch_is_a_switch 
    errors.add(:switch_id, "is not a switch") unless switch.node_type.is_switch? 
  end 
  def same_location
    if node.datacenter_id != switch.datacenter_id 
      errors.add(:switch_id, "is not in the same datacenter as node") 
    end
  end
  def self.plug(sw,node,port)
      unless node.class == Node and sw.class == Node then
        raise NetworkSwitchPortException.new('error: plug(switch, node, port)')
      end
     create({:switch => sw, :node => node, :port => port.upcase })
  end
end

class SerialConsole < ActiveRecord::Base
  has_paper_trail
  belongs_to :node, :foreign_key => 'node_id', :class_name => 'Node'
  belongs_to :scs, :foreign_key => 'scs_id', :class_name => 'Node'
  validates_uniqueness_of :scs_id, :scope => [:scs_id, :port]

  def self.plug_node_into_scs(*args) 
      plug_node_into_serial_console(*args)
  end
  def self.plug_node_into_serial_console(p_node, p_scs, p_outlet)
    if p_node == p_scs or not p_scs.node_type.is_serial_console? and ( not p_node.node_type.can_has_serial_console?) then 
    raise Exception.new("Failed serial console #{p_scs.node_type.is_serial_console?} and node not #{p_node.node_type.is_serial_console?}")
    end
    SerialConsole.create({:scs_id => p_scs.id, :node_id => p_node.id, :port => p_outlet})
  end
end

class SerialBaudRate < ActiveRecord::Base
  set_primary_key 'speed'
  def to_label
    speed.to_s
  end
end

class Version
 def self.sparksdata
    sql = "select coalesce(n,0) as n from (select count(*) as n,
created_at::date as d   from versions group by 2 order by 2) b 
right outer join ( select current_date - s.a as dates from
generate_series(0,365,1) as s(a) ) c on dates = d ";
    values =  connection.select_values(sql).map{|x| x.to_i}
    sql = "select sum(n),avg(n)::int,max(n), count(n) 
      from (select count(*) as n, created_at::date 
          from versions where created_at > date_trunc('year',now())
          group by 2 order by 2 desc) a "
   stats =  connection.select_all(sql).first
   avg = stats["avg"].to_i
   sum = stats["sum"].to_i
   "TopfunkySparkline('chart', 
                  #{values.inspect},
                   {
                     width: #{values.length}, 
                     height: #{avg * 5}, 
                     title:'Activity', 
                     target: #{avg * 2}, 
                     good_threshold: #{avg} } );"

  end
  def self.top_ten_users
    x = "select name, count(*) from users 
                join versions on user_id = whodunnit::int 
                where whodunnit ~ E'^[0-9][0-9]*$' and versions.created_at > (current_date - 7) 
                group by 1 order by 2 desc limit 10"
    connection.select_all(x)
  end
  def self.find_older(n=0, max=500)
    n = 0 if n < 0
    lim = [max-n,0].max 
    find(:all, :order => "id desc", :offset=> n, :limit => lim ) 
  end
  def self.find_latest 
    #@versions = Version.find_latest
    find(:all, :conditions => ["created_at > current_date"], :order => "id desc") 
  end
  def when
    created_at
  end 
  def what
    item_type
  end
  def how  
    case event
    when "destroy" then 'destroyed'
    when "create" then 'created'
    when "update" then 'updated' 
    else 'something'
    end
  end
  # returns a associated user if it is found in the Users table
  def who 
    version_user.to_label
  end
  def version_user
    if whodunnit.blank?
      return User.new(:name => "PROBABLY CHAD")
    elsif whodunnit.to_i > 0
      return User.find_by_user_id(whodunnit.to_i) || User.new(:name => "Unknown User: #{whodunnit.to_i}")
    else
      matches = /[^(]*\((.*)\).*/.match(whodunnit)  # user login is between parentheses, example: "irb(syeo)"
      if matches[1] == 'root' and whodunnit.include? 'gen_layout'
        return User.new(:name => 'gen_layout')
      else
        return User.find(:first, :conditions => {:login => matches[1]})
      end
    end
  end
end
