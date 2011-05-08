
#Blueprints - Generating Objects
#A blueprint describes how to generate an object. The idea is that you let the blueprint take 
#care of making up values for attributes that you don't care about in your test, leaving you to focus on the just the things that you're testing.
#A simple blueprint might look like this:
#Post.blueprint do
#  title  { Sham.title }
#  author { Sham.name }
#  body   { Sham.body }
#end
#    ip_address inet

require 'machinist/active_record'
require 'sham'

def pick_number(first,last)
  Range.new(first,last).to_a.rand
end
def random_tag
  "%s%s%d%s%d%s%s" % [pick_number('a','z'), pick_number('A','J'),
                    pick_number(10,99),pick_number('G','N'),
                    pick_number(10,99),pick_number('N','Z'),pick_number('a','z')]
end
def random_ip_in_range(network)
  min_ip = IPAddr.new(network.gateway)
  max_ip = IPAddr.new(network.ip_range) | ~IPAddr.new(network.netmask)
  rand_ip_i = rand(max_ip.to_i - min_ip.to_i + 1) + min_ip.to_i
  IPAddr.new(rand_ip_i, Socket::AF_INET).to_s
end
def random_datacenter
  Datacenter.first(:order => 'random()')
end

# creates relevant objects for a proper node and returns Node.plan hash
def prepare_proper_node(*args)
  node = Node.plan *args
  dc = Datacenter.find(node[:datacenter_id])
  mgmt_type = NetworkType.find_by_name('mgmt')
  Network.make(:description => "mgmt #{dc.name}",:vlan => 4000,:network_type => mgmt_type)
  node
end
def make_proper_node(*args)
  node = prepare_proper_node *args 
  Node.create_node_by_id(node).save rescue raise Exception.new "Couldn't save node!"
  node = Node.find_by_hostname_and_datacenter_id(node[:hostname], node[:datacenter_id])
  node.add_lan_nic(Sham.mac_address, 'eth0') if node.node_type.is_physical?
  node
end

Sham.define do
  #Sham.coin_toss(:unique => false) { rand(2) == 0 ? 'heads' : 'tails' }
  whole_number { Faker.numerify('#####').to_i } 
  title { Faker::Lorem.words(5).join(' ') }
  name { Faker::Internet.domain_word } 
  fullname  { Faker::Name.first_name }
  email { Faker::Internet.email }
  tag { random_tag }
  body  { Faker::Lorem.paragraphs(3).join("\n\n") }
  description  { Faker::Lorem.sentence }
  vlan(:unique=>false)  { pick_number(7,100) }
  eth(:unique => false) { "eth" + pick_number(0,6).to_s }
  mac_address { "ca:fe:37:%02X:%02X:%02X" % [rand(0x7f), rand(0xff), rand(0xff)] }
  nic_network_type(:unique => false ) { rand(2) == 0 ? 'lan': 'san' } 
  tcp_port { pick_number(9000,10000) }
  ha_tcp_port(:unique => false )  { pick_number(22,1024) }
  ram_size(:unique => false) { [256,512,1024,4096].random_element }
  cpu_cores { [1,2,4,6,16,8,24].random_element }
  os_distro { Faker::Lorem.words(2).join(' ') }
  pdu_outlet { pick_number(1,30) }
  scs_port { pick_number(1,30) } 
  nsp_port { "%s%s" % [ (('A'..'L').to_a + ('a'..'l').to_a).random_element,pick_number(0,99) ] } 
  hostname { Faker::Internet.domain_word } 
  system_name { Faker::Internet.domain_word } 
  cluster_name { Faker::Internet.domain_word[0..15] }
  ip_range { "%d.%d.%d.0/24" % [ pick_number(10,215), pick_number(0,254), pick_number(0,254)] }
  url_schema { ["http",'https','ldap','postgresql','xmpp'].random_element  }
  url { "http://#{Faker::Internet.domain_name}/" }
  domain_name { Faker::Internet.domain_name }
  ha_ip_address { "%s.%d" % [ ['10.10.10','209.60.186'].random_element, pick_number(21,254) ] }
  # network_type(:unique => false) { ["campus1", 'public1'].random_element }
  ip_address { "%s.%d" % [ ['1.2.3','3.1.8'].random_element, pick_number(21,254) ] }
end


#class Cluster < ActiveRecord::Base
#  has_and_belongs_to_many :nodes, :join_table => 'cluster_nodes',:order => 'hostname'
#      unless cluster.class == Cluster then
#      unless node.class == Node then
#      unless node.class == Node then
#      unless node.class == Node then
#      unless node.class == Node and src.class == Cluster then
#class Nic < ActiveRecord::Base
#	has_and_belongs_to_many :nodes, :join_table => "node_nics"
#class NodeNic < ActiveRecord::Base
#class Node < ActiveRecord::Base
#  has_and_belongs_to_many  :nics, :join_table => 'node_nics'
#  belongs_to :node_type
#  has_and_belongs_to_many :clusters , :join_table => 'cluster_nodes' 
#  has_and_belongs_to_many :sans, :join_table => 'san_nodes' 
#  belongs_to :os_version
#  belongs_to :location
#  belongs_to :datacenter
#  belongs_to :model, :foreign_key => 'model_id', :class_name => "CnuMachineModel"
#  has_one :xen_host, :foreign_key => 'host_id', :class_name => "XenMapping"
#  has_one :xen_guest, :foreign_key => 'guest_id', :class_name => "XenMapping"
#  has_many :xen_guests, :foreign_key => 'host_id', :class_name => "XenMapping"
#  has_and_belongs_to_many  :disks, :join_table => 'node_disks'
#class Service < ActiveRecord::Base
#  belongs_to :protocol
#  has_many :depends_on_relationships, :foreign_key => 'parent_id', :class_name => 'ServiceDependency'
#  has_many :required_by_relationships, :foreign_key => 'child_id', :class_name => 'ServiceDependency'
#  has_many :depends_on, :through => :depends_on_relationships, :class_name => 'Service', :source => "child"
#  has_many :required_by, :through => :required_by_relationships, :class_name => 'Service', :source => "parent"
#
Node.blueprint do
  hostname { Sham.hostname }
  datacenter { random_datacenter }
#CREATE TABLE nodes (
#    serial_no text,  # name
#    mgmt_ip_address text,
#    hostname text,  # name
#    service_tag text  # name
end  
Node.blueprint(:physical) do
  node_type { NodeType.find_by_name('physical') }
  os_version { OsVersion.make } 
end  
Node.blueprint(:virtual) do
  node_type { NodeType.find_by_name('virtual') }
  os_version { OsVersion.make } 
end  
Node.blueprint(:switch) do
  node_type { NodeType.find_by_name('switch') }
end  
Node.blueprint(:pdu) do
  node_type { NodeType.find_by_name('pdu') }
end  
Node.blueprint(:serial_console) do
  node_type { NodeType.serial_console }
end  
Node.blueprint(:load_balancer) do
  node_type { NodeType.load_blancer }
end  
LiveXenMap.blueprint do
  host = Node.make :physical
  node = Node.make(:virtual, :datacenter_id => host.datacenter_id)
  domo { host }
  domu { node }
  client_name { node.hostname }
end

ClusterNode.blueprint do
end

Nic.blueprint do 
  mac_address 
  port_name  { Sham.eth }
  network_type {'lan'}
end
Nic.blueprint(:san) do
  network_type {'san'}
end
Cluster.blueprint do 
  cluster_name { Sham.cluster_name }
  description 
  vlan
#    ip_range cidr,
  fw_mark { Sham.whole_number }
#    load_balanced boolean DEFAULT true
end
Service.blueprint do
  name 
  description 
  url { Sham.url } 
 ip_address { Sham.ha_ip_address }
    service_port { Sham.tcp_port }
    local_port  { Sham.tcp_port } 
    availability { ["public", "campus"].rand } 
    protocol { Protocol.find_by_proto('tcp') } 
#    check_url text,
#    check_port integer,
#    trending_url text,
#    glb_availablilty text,
#    protocol_id integer DEFAULT 1,
#    not_unique integer DEFAULT 1
end
Bootstrap.blueprint do
  dmesg { Sham.body }
  dmidecode { Sham.body   }
  proc_meminfo { Sham.body } 
  proc_cpuinfo { Sham.body } 
  service_tag { Sham.tag  } 
  uuid_tag  {Sham.tag  }
  product_name {Sham.title }
end 

San.blueprint do 
  san_name  { Sham.system_name }
  description 
  network { Network.make(:san) }
end

SanNode.blueprint do
  _san = San.make
  _san_nic = Nic.plan(:san)
  _node = Node.make(:virtual, :datacenter => _san.magic_datacenter)
  _node.add_san_nic(_san_nic[:mac_address], _san_nic[:port_name])
  san { _san }
  node { _node }
  ip_address { IpAddress.make(:network => _san.network) }
end

#class SanNode < ActiveRecord::Base
#  belongs_to :node
#  belongs_to :san

ServiceDependency.blueprint do 
  parent { Service.make } 
  child { Service.make }
end 
Distribution.blueprint do 
  name { Sham.os_distro }
end
OsVersion.blueprint do 
  # distribution { Sham.os_distro }
  distribution { Distribution.make.name }
  kernel { Sham.tag  }
end
Location.blueprint do 
  datacenter { random_datacenter }
end

# Use only when you _really_ want to _create_ a new Datacenter. If you just
# need to grab a dc, use random_datacenter or Datacenter.find_by...
#
# (The Datacenter model has acts_as_static_record and will be cached even
#  with transact. fixtures turned on. Be careful!)
Datacenter.blueprint do
  name { 'lat' }
end

XenMapping.blueprint do 
  dc = random_datacenter
  host { make_proper_node(:physical, :datacenter_id => dc.id)  }
  guest { Node.make(:virtual, :datacenter_id => dc.id)  }
end
Pdu.blueprint do
  node { Node.make(:physical, :model => CnuMachineModel.make) } 
  pdu  { Node.make(:pdu) } 
  outlet_no { Sham.pdu_outlet } 
end
CnuMachineModel.blueprint do 
  megabytes_memory { Sham.ram_size }
  cpu_cores  { Sham.cpu_cores }
  manufacturer { Sham.name } 
  model_no { Sham.name } 
  serial_baud_rate { 57600 } 
  serial_dce_dte { true  } 
  serial_flow_control { 'none'}
  power_supplies { 2 }
end
Disk.blueprint  do
  total_megabytes {Sham.ram_size }
  mount_point { '/' }
  sparse { false }
  read_only { false }
  mount_options { '' }
end
Disk.blueprint(:iscsi)  do
  name { 'iqn.2001-05.com.equallogic:0-8a0906-f1e023602-a59fa1797234b986-blog-web' } 
  disk_type { 'iscsi' }
end
Disk.blueprint(:file )  do
  name { 'disk.img'}
  disk_type { 'file' }
end
NodeDisk.blueprint do
  disk { Disk.make(:file) }
  node { Node.make(:virtual) }
  block_name { 'sda1' }
end
#DiskType.blueprint do
#  disk_type {['direct','file','iscsi'].rand }
#end 
NetworkSwitchPort.blueprint do 
  switch { Node.make(:switch) } 
  node { Node.make(:physical, :datacenter_id => switch.datacenter_id) } 
  port { Sham.nsp_port }
end

SerialConsole.blueprint do
  node { Node.make(:physical) } 
  scs { Node.make(:serial_console) }
  port { Sham.scs_port } 
end
#class SerialBaudRate < ActiveRecord::Base

Rampart.blueprint do
  has_public_ip { false }
  has_service_ip { false }
  node { Node.make :virtual }
end

RampartService.blueprint do
  network { Sham.ip_range }
  description { Sham.description }
end

User.blueprint do
  login { 'admin' }
  name { Sham.fullname } 
  email { "#{Sham.tag}@test.example.org" } 
  password { 'password1' }
  password_confirmation { 'password1' }
end

#def make_admin_user
#  u = User.make  
#  r = Role.find_by_name('admin')
#  u.roles << r
#  u.save
#  u
#end

DatabaseConfig.blueprint do
  name { Sham.system_name }
 max_connections { pick_number(100,1000) }
 disk_size {'1Gb'}
 work_mem {'1Gb'} 
 maintenance_mem {'1Gb'} 
# shared_buffers {'1Gb'} 
# temp_buffers  {'1Gb'} 
# effective_cache_size {'1Gb'} 
 search_path {'customer public'} 
 timezone  { 'CST' }
 log_min_duration_statement {'1s'}
end 

DatabaseCluster.blueprint do
  name
  description { Faker::Lorem.sentence(8) }
  version { DatabaseVersion.all.rand.to_label }
  service { Service.make }
  database_config { DatabaseConfig.make }
end

DatabaseName.blueprint do
  name
  description { Faker::Lorem.sentence(8) }
end

Network.blueprint do
  description
  ip_range
  network_type  { NetworkType.find_by_name('private') }
  vlan 
end
Network.blueprint(:san) do
  network_type  { NetworkType.find_by_name('san') }
end
Network.blueprint(:public) do
  network_type  { NetworkType.find_by_name('public') }
end
IpAddress.blueprint do
  n = Network.make
  network { n } 
  ip_address { random_ip_in_range(n) }
  default_network { false } 
end
