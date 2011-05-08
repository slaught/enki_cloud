
#create table node_acls
#  , acl_id int references acls (acl_id)
#  , node_id int references nodes (node_id) 
#  , unique ( acl_id, node_id)
class NodeAcl < ActiveRecord::Base
  # set_primary_key 'node_acl_id'
  belongs_to :acl 
  belongs_to :node
end


