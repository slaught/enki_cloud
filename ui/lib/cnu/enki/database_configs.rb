#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class DatabaseConfigs
  public
  def self.generate(directory)
    t = Time.now()
    new().generate(directory) 
    print_runtime(t,'Database Configs')
  end

  def generate(dir)
    # for each dbclsuter
    for c in DatabaseCluster.all 
      d = File.join(dir, c.name )
      mkdir( d ) 
      get_url_dir_output("database_clusters/config", c.id, d, c.postgresql_conf_filename )
    end
  end
end

end # end module
