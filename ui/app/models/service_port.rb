#
#--     sid, pid, local_port, unique_proxy_id(?) 
#create table service_ports
#(
#  id serial primary key
#  , service_id int references services (service_id)
#  , port_id int references ip_ports ( port_id)
#  , local_port int
#  , has_proxy int default 0
#  , unique (local_port, has_proxy)
#  , unique (service_id, port_id )
#);
class ServicePort < ActiveRecord::Base
  set_primary_key 'id'
  belongs_to :service
  belongs_to :ip_port
  # local_port int
  def has_proxy?
    has_proxy > 0 # has_proxy int default 0
  end
  # unique (local_port, has_proxy)
  # unique (service_id, port_id )
end

