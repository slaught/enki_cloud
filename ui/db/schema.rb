# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090729155118) do

  create_table "audits", :force => true do |t|
    t.integer  "auditable_id"
    t.string   "auditable_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "username"
    t.string   "action"
    t.text     "changes"
    t.integer  "version",        :default => 0
    t.datetime "created_at"
  end

  add_index "audits", ["auditable_id", "auditable_type"], :name => "auditable_index"
  add_index "audits", ["created_at"], :name => "index_audits_on_created_at"
  add_index "audits", ["user_id", "user_type"], :name => "user_index"

  create_table "cluster_nodes", :id => false, :force => true do |t|
    t.integer "cluster_id",                :null => false
    t.integer "node_id",                   :null => false
    t.string  "ip_address", :limit => nil
  end

  add_index "cluster_nodes", ["cluster_id", "ip_address"], :name => "cluster_nodes_ip_address_key", :unique => true

  create_table "cluster_services", :id => false, :force => true do |t|
    t.integer "cluster_id", :null => false
    t.integer "service_id", :null => false
  end

  create_table "clusters", :primary_key => "cluster_id", :force => true do |t|
    t.string  "cluster_name",  :limit => 16
    t.text    "description"
    t.integer "vlan"
    t.string  "ip_range",      :limit => nil
    t.integer "fw_mark"
    t.boolean "load_balanced",                :default => true
  end

  add_index "clusters", ["fw_mark"], :name => "clusters__fw_mark__uniq", :unique => true
  add_index "clusters", ["cluster_name"], :name => "clusters_cluster_name_key", :unique => true

  create_table "cnu_machine_models", :primary_key => "model_id", :force => true do |t|
    t.integer "megabytes_memory"
    t.integer "power_supplies"
    t.integer "cpu_cores"
    t.integer "cpu_speed_megahertz"
    t.integer "network_interfaces"
    t.text    "model_no"
    t.text    "manufacturer"
    t.integer "max_amps_used"
    t.integer "max_btu_per_hour"
    t.text    "serial_console_type"
    t.integer "rack_size"
  end

  create_table "datacenters", :primary_key => "datacenter_id", :force => true do |t|
    t.text "name"
  end

  create_table "disk_types", :force => true do |t|
    t.text "disk_type"
  end

  add_index "disk_types", ["disk_type"], :name => "disk_types_disk_type_key", :unique => true

  create_table "disks", :primary_key => "disk_id", :force => true do |t|
    t.integer "total_megabytes"
    t.text    "mount_point"
    t.boolean "sparse",          :default => false
    t.text    "name",                               :null => false
    t.text    "disk_type",                          :null => false
  end

  create_table "distributions", :force => true do |t|
    t.text "name"
  end

  add_index "distributions", ["name"], :name => "distributions_name_key", :unique => true

  create_table "locations", :primary_key => "location_id", :force => true do |t|
    t.integer "datacenter_id"
    t.integer "rack"
    t.integer "rack_position_bottom"
    t.integer "rack_position_top"
  end

  create_table "network_switch_ports", :force => true do |t|
    t.integer "node_id",                 :null => false
    t.integer "switch_id",               :null => false
    t.string  "port",      :limit => 10, :null => false
  end

  add_index "network_switch_ports", ["port", "switch_id"], :name => "network_switch_ports_switch_id_key", :unique => true

  create_table "nics", :primary_key => "nic_id", :force => true do |t|
    t.text   "port_name"
    t.text   "network_type"
    t.string "mac_address",  :limit => nil
  end

  add_index "nics", ["mac_address"], :name => "nics_mac_address_uniq", :unique => true

  create_table "node_disks", :id => false, :force => true do |t|
    t.integer "node_id", :null => false
    t.integer "disk_id", :null => false
  end

  create_table "node_nics", :id => false, :force => true do |t|
    t.integer "node_id", :null => false
    t.integer "nic_id",  :null => false
  end

  create_table "node_type", :primary_key => "node_type_id", :force => true do |t|
    t.text "node_type"
  end

  create_table "nodes", :primary_key => "node_id", :force => true do |t|
    t.text    "serial_no"
    t.integer "model_id"
    t.integer "node_type_id"
    t.integer "location_id"
    t.text    "serial_console"
    t.text    "mgmt_ip_address"
    t.text    "hostname"
    t.integer "os_version_id"
  end

  create_table "os_versions", :force => true do |t|
    t.text "description"
    t.text "distribution"
    t.text "kernel"
  end

  add_index "os_versions", ["distribution", "kernel"], :name => "os_versions_distribution_key", :unique => true

  create_table "pdus", :force => true do |t|
    t.integer "ps_id"
    t.integer "pdu_id"
    t.integer "outlet_no", :limit => 2
  end

  create_table "protocols", :primary_key => "protocol_id", :force => true do |t|
    t.string "proto", :limit => 4
  end

  add_index "protocols", ["proto"], :name => "protocols_proto_key", :unique => true

  create_table "roles", :primary_key => "role_id", :force => true do |t|
    t.text    "name"
    t.text    "description"
    t.boolean "grant_select"
    t.boolean "grant_update"
    t.boolean "grant_delete"
    t.boolean "grant_create"
    t.boolean "grant_insert"
  end

  create_table "san_nodes", :id => false, :force => true do |t|
    t.integer "san_id",                    :null => false
    t.integer "node_id",                   :null => false
    t.string  "ip_address", :limit => nil, :null => false
  end

  add_index "san_nodes", ["ip_address"], :name => "san_nodes_ip_address_uniq", :unique => true

  create_table "sans", :primary_key => "san_id", :force => true do |t|
    t.string  "san_name",    :limit => 16
    t.text    "description"
    t.string  "ip_range",    :limit => nil
    t.integer "vlan"
  end

  create_table "service_locations", :id => false, :force => true do |t|
    t.integer "service_id",    :null => false
    t.integer "datacenter_id", :null => false
  end

  create_table "services", :primary_key => "service_id", :force => true do |t|
    t.text    "name"
    t.text    "description"
    t.text    "url"
    t.text    "ip_address"
    t.integer "service_port"
    t.text    "availability"
    t.text    "check_url"
    t.integer "check_port"
    t.text    "trending_url"
    t.text    "glb_availablilty"
    t.integer "protocol_id",      :default => 1
    t.integer "local_port"
    t.integer "not_unique",       :default => 1
  end

  add_index "services", ["local_port", "not_unique", "protocol_id"], :name => "local_port_unique", :unique => true
  add_index "services", ["ip_address", "protocol_id", "service_port"], :name => "services_ip_port_proto_key", :unique => true

  create_table "sessions", :id => false, :force => true do |t|
    t.text     "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "sessions_session_id_idx"
  add_index "sessions", ["updated_at"], :name => "sessions_updated_at_idx"

  create_table "user_roles", :force => true do |t|
    t.integer "user_id"
    t.integer "role_id"
  end

  add_index "user_roles", ["role_id", "user_id"], :name => "user_roles_user_id_key", :unique => true

  create_table "users", :primary_key => "user_id", :force => true do |t|
    t.text     "login",                                   :null => false
    t.text     "name"
    t.text     "email"
    t.text     "crypted_password"
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "remember_token"
    t.datetime "remember_token_expires_at"
  end

  add_index "users", ["login"], :name => "users_login_key", :unique => true

  create_table "versions", :force => true do |t|
    t.string   "item_type",  :null => false
    t.integer  "item_id",    :null => false
    t.string   "event",      :null => false
    t.string   "whodunnit"
    t.text     "object"
    t.datetime "created_at"
  end

  add_index "versions", ["item_id", "item_type"], :name => "index_versions_on_item_type_and_item_id"

  create_table "xen_mappings", :force => true do |t|
    t.integer "host_id",  :null => false
    t.integer "guest_id", :null => false
  end

  add_index "xen_mappings", ["guest_id"], :name => "xen_mappings_guest_id_key", :unique => true
  add_index "xen_mappings", ["guest_id", "host_id"], :name => "xen_mappings_host_id_key", :unique => true

end
