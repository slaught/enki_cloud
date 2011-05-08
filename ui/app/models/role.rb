class Role < ActiveRecord::Base
  set_primary_key 'role_id'
  has_many :user_roles
  has_many :users, :through => :user_roles

end

