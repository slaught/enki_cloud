class LiveXenMap < ActiveRecord::Base
  set_primary_key 'live_xen_map_id'

  # do not track verision changes

  belongs_to :domo, :foreign_key => "host_id", :class_name => "Node"
  belongs_to :domu, :foreign_key => "client_id", :class_name => "Node"
end
