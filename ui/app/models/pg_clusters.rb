
require 'rubygems'
require 'active_record'
require 'active_support'


class DatabaseVersion < ActiveRecord::Base
#-- insert into cnu_net.pg_versions (version) values (8.2),(8.3),(8.4),(9.0);
  def to_label
      version.to_s
  end
  def self.select_options
    find(:all).map {|v| [v.version,v.version] }
  end
end

class DatabaseConfig < ActiveRecord::Base
  set_primary_key 'database_config_id' 
  has_paper_trail
  validates_numericality_of :max_connections, :only_integer => true, :greater_than_or_equal_to => 50, :less_than => 2001

  def to_label
    name.strip
  end
  def to_s
    to_label
  end
  def format_search_path
    user_path = search_path.to_s.split(' ')
    p = ['"$user"','public', user_path].flatten
    p.join(',')
  end
#, max_connections int 
# 
#, port int 
#, disk_size text
#, work_mem text
#, maintenance_mem  text
#, shared_buffers  text
#, temp_buffers   text
#, effective_cache_size text
#, search_path text
#, timezone  text
#, log_min_duration_statement text
end

class DatabaseClusterDatabaseName < ActiveRecord::Base
  before_validation_on_create 'self.id = 1' # for no primary key
  has_paper_trail
  belongs_to :database_cluster
  belongs_to :database_name
end

class  DatabaseName < ActiveRecord::Base
  set_primary_key 'database_name_id'
  has_paper_trail
  validates_length_of :description , :minimum => 5
  validates_length_of :name, :within  => 2..32
  validates_format_of :name, :with => /\A[A-Za-z][A-Za-z_0-9]*[A-Za-z0-9]\Z/ , :message => 'has spaces or other non-valid characters'
  validates_format_of :name, :with => /[^_]\Z/, :message => "has underscore at the end"
  validates_format_of :name, :with => /\A[^_]/, :message => "starts with an underscore"
  validates_format_of :name, :with => /\A[^ \t]+\Z/, :message => "has spaces"
  has_and_belongs_to_many :database_clusters , :join_table => 'database_cluster_database_names' 
  def to_label
      name
  end
end 

class DatabaseAcl < ActiveRecord::Base
 # before_validation_on_create 'self.id = 1' # for no primary key
  set_primary_key 'database_acl_id'
  has_paper_trail
  belongs_to :database_access    
  belongs_to :database_name 
  belongs_to :database_cluster 
end

class DatabaseAccessDatabaseCluster < ActiveRecord::Base
end


class DatabaseAccess < ActiveRecord::Base
  set_primary_key 'database_access_id'
  has_paper_trail
  belongs_to :node
# FIXME
# XXX  belongs_to :network
  
  has_many :database_clusters , :through => DatabaseAccessDatabaseCluster
#  has_and_belongs_to_many :database_clusters , :join_table => 'database_access_pg_clusters' 

# , node_id    int references nodes (node_id) 
# , network_id int -- references networks (network_id)
# , inet_addr inet 
# , allow  boolean -- false is a deny 
# -- , method text (md5,ldap,krb, ident)
# , rolename text default 'all'::text not null
# -- , force_order or rules
# , check ( (node_id is null and network_id is not null) 
#       or (node_id is not null and network_id is null) )
end


class DatabaseCluster < ActiveRecord::Base
  set_primary_key 'database_cluster_id'
  has_paper_trail

  validates_presence_of :service
  validates_presence_of :database_config
  validates_length_of :name, :within  => 2..24
#  validates_format_of :name, :with => /\A[a-z][-a-z0-9]*[a-z0-9]\Z/ , :message => 'has spaces or other invalid letters'
#  validates_format_of :name, :with => /\A[^_]+\Z/,:message => "has underscore"
#  validates_format_of :name, :with => /\A[^ \t]+\Z/, :message => "has spaces"
#  validates_format_of :name, :with => /^[^A-Z]+$/, :message => "has capital letters"
  validates_length_of :description , :minimum => 5
  validates_numericality_of :version, :greater_than_or_equal_to => 8.3, :less_than => 10.0, :message => 'not a valid version number'

  has_and_belongs_to_many :database_names, :join_table => 'database_cluster_database_names', :order => :name
  belongs_to :service #service_id int refs cnu_net.services(service_id) 
  belongs_to :database_config #pg_config_id int refs pg_configs(pg_config_id) 

  def active?
    service.active? and not database_names.empty?
  end
  def config
    database_config
  end
  def databases
    database_names
  end
  def to_label
    "#{version}/#{name}"
  end
  def postgresql_conf_filename
      "#{name}-postgresql.conf"
  end
  def port
    service.localport
  end
  def max_connections
    database_config.max_connections
  end
  def syslog_ident
      "pg_#{name}_#{version}"
  end
  def archive_mode
      if archive? then
        'on'
      else
        'off'
      end
  end
  def bgwriter_lru_maxpages
    if name =~ /us/ || name =~ /uk/
      return 1000
    else
      return 100
    end
  end
end
#  has_and_belongs_to_many :nodes, :join_table => 'cluster_nodes',:order => 'hostname'
#  has_many :cluster_nodes
#  has_many :cluster_services
#  has_many :services, :through => :cluster_services


