#-- port_id, port, protocol, uri schema.
#create table ip_ports (
#  port_id serial primary key
#  , port int -- | port_range
##  , protocol_id int references protocols (protocol_id)
#  , uri_schema text not null
#  , description text 
###  , unique (port, protocol_id)
class IpPort < ActiveRecord::Base
  set_primary_key 'port_id'
  belongs_to :protocol
  # validate port/protocol is unique
  def firewall_format(sep=':')
	  [protocol.name,sep,port].join('')
  end

#insert into ip_ports (port, protocol_id, uri_schema)
#values
#(22, get_protocol('tcp'), 'ssh'),
#(80, get_protocol('tcp'), 'http'),
#(443, get_protocol('tcp'), 'https'),
#(161, get_protocol('tcp'), 'snmp'),
#(161, get_protocol('udp'), 'snmp'),
#(9102, get_protocol('tcp'), 'backup') ;
end

