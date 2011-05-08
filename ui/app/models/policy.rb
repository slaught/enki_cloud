#-- policies:
#--   label, group of rules to permit or not-permit 
#--      applying to an object type?, metwork_type or node_type
#--  one policy per to permit one to deny for a given object type
#create table policies 
#  policy_id serial primary key
#  , name text not null
#  , permit boolean  not null -- permit t, deny f
#  , policy_object_type text -- NetworkType| NodeType |...
#  , object_type_id int  -- points to value in network_types or node_type table
#  check ( policy_object_type  IN ( 'NetworkType' , 'NodeType') ) 
#-- add trigger to check object_type_id is correct
#create table policy_acls 
#  id serial 
#  , policy_id int references policies (policy_id) 
#  , acl_id int references acls (acl_id)
#  , primary key ( policy_id, acl_id)
#
#-- policies:
#--   label, group of rules to permit or not-permit 
#--      applying to an object type?, metwork_type or node_type
#--  one policy per to permit one to deny for a given object type
class Policy < ActiveRecord::Base 
  set_primary_key 'policy_id'
  has_and_belongs_to_many :acls, :join_table => 'policy_acls'
  #, name text not null
  #, permit_deny boolean  -- permit t, deny f
  #, policy_object_type text -- NetworkType| NodeType |...
  #, object_type_id int  -- points to value in network_types or node_type table
  #-- , unique ( permit_deny, policy_object_type, object_type_id)
end
class Policy 
  def apply_policy(obj)
    return nil unless  "#{obj.class}Type" == policy_object_type
    new_acl = acls - obj.acls 
    obj.acls << new_acl 
    return new_acl
  end
end
class PolicyAcl < ActiveRecord::Base
#  id serial 
  belongs_to :policy #   , policy_id int references policies (policy_id) 
  belongs_to :acl    #, acl_id int references rules (rule_id)
  #, primary_key ( policy_id, rule_id)
end
