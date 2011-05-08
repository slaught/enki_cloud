#create table network_acls
#  , acl_id int references acls (acl_id)
#  , network_id int references networks (network_id) 
#  , unique ( acl_id, network_id)
class NetworkAcl < ActiveRecord::Base
#   set_primary_key 'network_acl_id'
  belongs_to :acl 
  belongs_to :network
end
