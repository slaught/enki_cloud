class NetworkType < ActiveRecord::Base
  set_primary_key 'network_type_id'
  acts_as_static_record
#insert into network_types (name) values
# ('dummy') ,
# ('mgmt')
#,('public')
#,('campus')
#,('private')
#,('cluster')
#,('routable')
#,('locale')
#,('neighborhood')
#;
  def self.routable_network
    NetworkType.find_by_name('routable')
  end
  def self.campus_network
    NetworkType.find_by_name('campus')
  end
  def self.private_network
    NetworkType.find_by_name('private')
  end
  def self.cluster_network
    NetworkType.find_by_name('cluster')
  end
  def self.public_network
    NetworkType.find_by_name('public')
  end
  def is_routable?
      name == 'routable'
  end
  def is_private?
      name == 'private'
  end
  def is_campus?
      name == 'campus'
  end
  def is_public?
      name == 'public'
  end
  def is_mgmt?
      name == 'mgmt'
  end
  def to_label
    "#{name} network"
  end
end

class Network < ActiveRecord::Base
  set_primary_key 'network_id'
  has_paper_trail  
  belongs_to :network_type

  has_and_belongs_to_many :acls, :join_table => 'network_acls'

  named_scope :san, { :joins => "join network_types using (network_type_id)",
                        :conditions => "network_types.name = 'san'" } 
  named_scope :mgmt, { :joins => "join network_types using (network_type_id)",
                        :conditions => "network_types.name = 'mgmt'" } 
#  named_scope :by_tag, lambda { |tag| { :conditions => ["uuid_tag = ? or service_tag =  ?", tag, tag] } }

#  has_many :nodes, :through => :node_networks
#  has_many :node_networks

  before_validation :clear_empty_attrs
  # validates_presence_of :network_type
  validates_presence_of :ip_range
  validates_format_of   :ip_range, :with => /\A[0-9][0-9\.\/]+[0-9]\Z/ , :message => 'is not an ip address.'
  validates_format_of   :ip_range, :with => /\A[^ \t]+\Z/, :message => "has spaces"
  validates_presence_of :description
  validates_length_of   :description , :minimum => 5
  validates_presence_of     :vlan
  validates_numericality_of :vlan, :only_integer => true, :greater_than_or_equal_to => 1, :less_than => 4096

  def self.datacenter_mgmt_network(datacenter)
    dc_id = case datacenter
    when Datacenter
      datacenter.id
    when String
      Datacenter.find_by_name(datacenter).id rescue raise Exception.new("No Datacenter named '#{datacenter}'")
    when Fixnum
      datacenter
    else
      raise TypeError.new("expecting Datacenter, String, Fixnum found #{datacenter.class}")
    end
    sql_f = "select datacenter_mgmt_network_id(#{dc_id}) as nid"
    mgmt_net_id = Network.connection.select_one(sql_f)['nid']
    if mgmt_net_id.nil? then
      raise Exception.new("No management network found for #{datacenter.to_label}")
    end
    Network.find(mgmt_net_id)
  end
#  validate , check ( network_gateway is null or network_gateway << ip_range )
  def to_label
    "#{ip_range} - #{vlan}"
  end
  def gateway
    return @gw_cache unless @gw_cache.nil?
    if network_gateway.nil?
      @gw_cache = ip_query(%Q[SELECT host(network(cast('#{ip_range}' as cidr))+1) as ip_address ]) 
    else
      @gw_cache = ip(network_gateway)
    end
  end
  def next_ip()
    #query  =  %Q[SELECT '#{ip_range}'::inet + s as ip_address 
    #        FROM generate_series(20, broadcast('#{ip_range}') - network('#{ip_range}'),1) as s(a) 
    #        EXCEPT (SELECT ip_address FROM node_networks 
    #        WHERE network_id = #{network_id} GROUP BY 1 ORDER BY 1) limit 1]
    unless network_type.is_private? then
      query  =  %Q[SELECT next_network_ip_address(#{network_id}) as ip_address]
      _ip = ip_query(query)
      new_ip(_ip) 
    else
      #  query  =  %Q[SELECT next_network_ip_address(#{network_id}) as ip_address]
      #  _ip = ip_query(query)
      #  new_ip(_ip) 
      nil
    end
  end
  def netmask()
    _netmask(ip_range)
  end
  def active?
      NetworkType.find_by_name('dummy') != network_type
  end
  def net_service(x)
    net_services(x)
  end
  def net_services(localinterface)
    if localinterface =~ /^\w+\d+$/ then
      iface  = localinterface
    else
      iface  = "#{localinterface}#{vlan}"
    end
    acls.map{|acl| acl.firewall_line(iface) }
  end

  def add_ip(ip)
    cidr = ip_range.split('/')[1]
    ip_final = "#{ip(ip.to_s)}/#{cidr}"
    new_ip = IpAddress.new(:ip_address => ip_final, :network_id => self.id)
    if new_ip.save
      new_ip
    else
      raise Exception.new(new_ip.errors.full_messages.join(' '))
    end
  end
  private 
  def new_ip(_ip)
    IpAddress.create(:network_id => self.network_id, :ip_address => _ip)
  end
    def _netmask(i)
      cidr = i.split('/')[1]
      return '255.255.255.0' if cidr.nil?
      IPAddr.new('255.255.255.255').mask(cidr).to_s
    end
    def last_octet(i)
      ip(i).split('.')[-2] + '.' +  ip(i).split('.')[-1]
    end
  def ip_query(query)
    s = connection.select_all(query).first
    if s.nil? then
      raise ActiveRecord::RecordNotFound.new("No more IP address in network #{ip_ranage}")
    else
      s["ip_address"]
    end
  end
    def ip(i)
      i.split('/')[0]
    end
#    def gw(ip)
#      ip_query(%Q[SELECT (select network('#{ip}152.16/30'::cidr)+1 as ip_address ]) 
#      # ip(ip).sub(/\.\d+$/,'.1')
#    end

  protected
  def clear_empty_attrs
    @attributes.each do |key,value|
      self[key] = nil if value.blank?
    end
  end
end

class IpAddress < ActiveRecord::Base
  set_primary_key 'ip_address_id'
  has_paper_trail  
  belongs_to :network 
  has_one :san_nodes  
  has_one :cluster_nodes  
  validates_presence_of :network 
  validates_presence_of :ip_address
  validate :ip_address_must_be_in_range
  #validate_on_create :ip_address_must_be_in_range
  #validate_on_update :ip_address_must_be_in_range
  include CNU::Conversion

  def gateway()
    network.gateway()
  end
  alias_method :gw, :gateway
  def netmask
    network.netmask()
  end
  alias_method :mask,:netmask 
  def cidr
      ip_address.split('/')[1]
  end
  def ip()
      ip_address.split('/')[0]
  end
  def to_s()
      ip
  end
  def to_label
    to_s
  end
  def to_i
    ip2dec(self.ip()).to_i
  end

private
  def ip_address_must_be_in_range
    query = %Q[SELECT inet '#{ip_address}' <<= inet '#{network.ip_range}' as in_range]
    result = connection.select_all(query).first
    if !result or result['in_range'] == 'f'
      errors.add(:ip_address, "is not in network's ip range")
    end
  end

end  

#alter table clusters add column network_id int ;
#alter table clusters add foreign key (network_id) references networks(network_id);
#
#alter table nodes add column mgmt_network_id int ; 
#alter table nodes add foreign key (mgmt_network_id) references networks (network_id);
#comment on column nodes.mgmt_network_id is 'mgmt network reference';

__END__
