authorization do
  role :guest do
    has_permission_on :node, :to => :read
    has_permission_on :xen, :to => [ :read, :compare ]
    has_permission_on :cluster, :to => :read
    has_permission_on :san , :to => :read
    has_permission_on :service, :to => :read
    has_permission_on :machine , :to => :read
    has_permission_on :bootstraps, :to => [:ready, :stage_one, :stage_two ]
    has_permission_on :cluster, :to => [:status, :dns ]
    has_permission_on :software, :to => [:read]
    has_permission_on :database_configs , :to => :read
    has_permission_on :database_clusters, :to => [ :read , :config ]
    has_permission_on :networks , :to => :read

    has_permission_on :rampart, :to => :read
#    has_permission_on :conferences, :to => :read do
#      if_attribute :published => true
#    end
#    has_permission_on :talks, :to => :read do
#      if_permitted_to :read, :conference
#    end
#    has_permission_on :users, :to => :create
#    has_permission_on :authorization_rules, :to => :read
#    has_permission_on :authorization_usages, :to => :read
  end
  
  role :operator do
    includes :guest
    has_permission_on :cluster, :to => [:read, :edit,:dns ]
    has_permission_on :node, :to => [:create, :edit, :read, :add_disks, :add_switch_ports, :manage_nics]
    has_permission_on :software, :to => [:create, :update, :create_dist, :update_dist, :new_dist, :new, :edit, :edit_dist]
    
#    has_permission_on :conference_attendees, :to => :create, :join_by => :and do
#      if_attribute :user => is {user}
#      if_permitted_to :read, :conference
#    end
#    has_permission_on :conference_attendees, :to => :delete do
#      if_attribute :user => is {user}
#    end
#    has_permission_on :talk_attendees, :to => :create do
#      if_attribute :talk => { :conference => { :attendees => contains {user} }},
#          :user => is {user}
#    end
#    has_permission_on :talk_attendees, :to => :delete do
#      if_attribute :user => is {user}
#    end
  end

  role :sysadmin do
    includes :operator
    has_permission_on :cluster, :to => [:update , :remove_node, :add_service, :add_node]
    has_permission_on :san, :to => [:read, :edit, :add_node]
    has_permission_on :service, :to => [:create, :read, :edit, :add_dependency, :del_dependency, :add_dependency_form ] 
    has_permission_on :bootstraps, :to => [:manage]
    has_permission_on :node do 
          to :create
          to :update
          to :read
          to :manage_disks
          to :manage_switch_ports
          to :manage_pdus
          to :manage_scs 
          to :manage_nics
          to :add_node_to_cluster
          to :del_node_from_cluster
          to :map_to_xen_host
          to :remove_from_xen_host
          to :remove_xen_guest
          to :add_xen_guest
          to :push_vlan
    end
    has_permission_on :machine, :to => :read
    has_permission_on :xen do
      to :manage
      to :map_to_host
      to :show_add_mapping_form
      to :hide_add_mapping_form
      to :add_new_mapping
      to :unmap_guest
    end
    has_permission_on :authorization_rules, :to => :read
    has_permission_on :rampart, :to => [:manage, :manage_rampart_services, :get_public_ip, :get_locale_ip]
  end
  role :nav_admin do
    has_permission_on :nodes, :to => :manage do
      if_attribute :datacenter => is { Datacenter.find_by_name('nav') }
    end
  end
  role :dba do
    includes :operator 
    has_permission_on :database_configs, :to => :manage 
    has_permission_on :database_names, :to => :manage 
    has_permission_on :database_clusters, :to => [:manage, :manage_db]
    has_permission_on :services, :to => [:remove_from_cluster, :add_to_cluster] do
      if_attribute :ha_protocol => is { 'postgresql' }
    end
    # has_permission_on :cluster, :to => :manage_services
  end
  role :engineer do
    includes :sysadmin
    # has_permission_on :cluster, :to => [:read, :update, :create, :manage_services,:manage_nodes,:change, :delete]
    has_permission_on :cluster, :to => [:read, :update, :create, :manage_nodes,:change, :delete]
    has_permission_on :service, :to => :manage
    has_permission_on :services, :to => :manage_clusters
    has_permission_on :san, :to => [:manage , :manage_nodes]
    has_permission_on :machine , :to => :manage 
    has_permission_on :xen, :to => :manage 
    has_permission_on :node do
      to :manage 
      to :manage_disks
      to :manage_switch_ports
      to :manage_nics
      to :manage_pdus
      to :manage_scs 
    has_permission_on :nodes, :to => :manage
    end
    has_permission_on :database_configs, :to => :manage 
    has_permission_on :database_names, :to => :manage 
    has_permission_on :database_clusters, :to => [:manage, :manage_db]
    has_permission_on :networks , :to => :manage
#    has_permission_on :pdu, :to => [:unplug_pdu]
#    has_permission_on :cluster  do
#      to :create 
#      to :manage_nodes
#      to :manage_services
#    end
#    has_permission_on [:conference_attendees, :talks, :talk_attendees], :to => :manage
    has_permission_on :push, :to => :deploy_all
  end

  role :network_admin do
    has_permission_on :networks , :to => :manage
  end
  
  role :admin do
    includes :engineer
    has_permission_on :node, :to => :manage
    has_permission_on :xen, :to => :manage 
    has_permission_on :cluster, :to => [:read, :update,:change, :create, :delete]
    has_permission_on [:node, :xen, :users ], :to => :manage
    has_permission_on :authorization_rules, :to => :read
    has_permission_on :authorization_usages, :to => :read
    has_permission_on :san, :to => :manage 
  end

  role :rampart_admin do
    has_permission_on :rampart, :to => :manage
    has_permission_on :rampart, :to => :manage_rampart_ip
  end

end


privileges do
  privilege :manage, :includes => [:create, :read, :update, :delete, :change ]
  privilege :manage_rampart_services, :includes => [:add_service, :remove_service]
  privilege :manage_db, :includes => [ :add_database, :remove_database, :config ]
  privilege :manage_nodes, :includes => [:add_node, :remove_node]
  privilege :manage_switch_ports, :includes => [:add_switch_port, :remove_switch_port]
  privilege :manage_disks, :includes => [:add_disk, :remove_disk ]
  privilege :manage_nics , :includes => [:add_nic , :remove_nic  ]
  # privilege :manage_services, :includes => [:add_service, :remove_service]
  privilege :manage_clusters, :includes => [:add_to_cluster, :remove_from_cluster]
  privilege :manage_pdus, :includes => [:plug_pdu, :unplug_pdu, :create, :destroy ]
  privilege :manage_scs , :includes => [:plug_serial_console, :unplug_serial_console, :create, :destroy ]
  privilege :manage_rampart_ip, :includes => [:get_public_ip_editable, :get_locale_ip_editable]
  privilege :unplug_serial_console, :includes => [:destroy]
  privilege :plug_serial_console, :includes => [:create]
  privilege :read,   :includes => [:index, :show, :list, :loc, :cls, :show_name, :stage_one, :stage_two, :ready, :host, :listjson, :status, :compare ]
  privilege :create, :includes => :new
  privilege :update, :includes => [:edit,:update_partial]
  privilege :delete, :includes => :destroy
  privilege :change, :includes => :update
  privilege :deploy_all, :includes => [:index, :list, :scs, :pdu, :host, :host_push]
end

