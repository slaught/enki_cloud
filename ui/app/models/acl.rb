#-- table acls
#-- ( acl_id, src ip_address, dest ip_addr, type)
#create table acls (
#  acl_id serial primary key
#  , source cidr default '0.0.0.0/0'::cidr not null
#  , destination int references networks (network_id) -- "::tcp:11301:eth2000"
#  , port_id int references ip_ports (port_id) not null
#  , permit  boolean default true -- false is deny
#  , unique (source, port_id)
#-- table acls
#-- ( acl_id, src ip_address, dest ip_addr, type)
#
# Each ACL should be unique. Duplicates can be confusing used 0.0.0.0/0 
class Acl < ActiveRecord::Base
  set_primary_key 'acl_id' 
  #, source cidr default '0.0.0.0/0'::cidr not null
  belongs_to  :port, :class_name => 'IpPort'

  def source_address
    if source == '0.0.0.0/0' then
      return ''
    else
      source.to_s
    end
  end
  def firewall_line(iface)
    # TODO: add in desination and source checking for net_filter
    if permit? then
    %Q(::#{port.firewall_format}:#{iface}) #"::tcp:22:vlan600"
    else
      ''
    end
  end
#  , destination int references networks (network_id) -- "::tcp:11301:eth2000"
#  , port_id int references ip_ports (port_id) not null
#  , permit  boolean default true -- false is deny
#  , unique (source, port_id)
end

__END__
create table ip_end_to_ends
(
  id serial primary key
  , protocol_id int REFERENCES protocols (protocol_id)
  , source_network_id int references networks (network_id) -- A 
  , source_port     int -- A
  , destination_network_id int references networks (network_id) -- B
  , destination_port int -- B
  -- , port_id int references ports ( port_id)
);


