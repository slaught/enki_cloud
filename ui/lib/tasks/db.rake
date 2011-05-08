def reload_db(db)
  sh "dropdb #{db};true"
  sh "createdb #{db}"
  sh psql "-f db/db_init.sql #{db}"
end
def prod(key)
  require 'yaml'
  hash = YAML::load_file("#{RAILS_ROOT}/config/database_production.yml")
  hash['production'][key]
end
def get_dump(out_file, schema_only)
  schema_switch = schema_only ? '-s' : ''
  sh "pg_dump -i -n cnu_net -h #{prod('host')} -f #{out_file} #{schema_switch} #{prod('database')}"
end
# set to ignore .psqlrc file and supress non-relevent messages
def psql(args)
  "psql -X -q #{args}"
end

namespace :db do
  desc "production dump" 
  task :production_db_dump do
    get_dump('db/prod_cnu_it.sql', false)
  end
  desc "production schema dump"
  task :production_schema_dump  do
    get_dump('db/cnu_it.sql', true)
  end

  desc "args: db=<db_name> file=<filename> Sets up a database with schema and minimalist seed data (defaults to test db)"
  task :sqlbuild do
    db = Rails::Configuration.new.database_configuration['test']['database']
    db = ENV['db'] if ENV.key?('db') 
    otherfile=ENV['file'] 
    reload_db(db)
    if ENV.key?('file') && File.exist?(otherfile)
      sh psql "-f #{otherfile} #{db}"
    else
      sh psql "-f db/cnu_it.sql #{db}"
      sh psql "-f db/seed_data.sql #{db}"
      if File.exist?('db/seed_data_private.sql')
         sh psql "-f db/seed_data_private.sql #{db}"
      end
      sh psql "-f db/test_db_additions.sql #{db}" if db == Rails::Configuration.new.database_configuration['test']['database']
    end
  end

  desc "Drops database (default: cnu_it_dev) and dumps in latest production data - opt_args: db=<db_name>"
  task :use_production_dump do
    require 'tempfile'
    db = Rails::Configuration.new.database_configuration['development']['database']
    db = ENV['db'] if ENV.key?('db')

    puts "Getting production dump..."
    tmp_file = Tempfile.new("temp_dump_#{rand(10000)}.sql")
    get_dump(tmp_file.path, false)
    puts "Getting production dump...Done"

    puts "Resetting and populating #{db}..."
    reload_db(db)
    sh "psql -f #{tmp_file.path} #{db}"

    tmp_file.delete
  end
end # end db namespace
