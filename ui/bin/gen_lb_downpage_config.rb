#!/usr/bin/ruby 

require 'network_nodes'

if $verbose.nil? then
  $verbose = true
end

def find_clusters
  Cluster.find_all_active.map{|c|
    if cluster_can_have_downpage?(c) then
        c
    else
      nil
    end
  }.compact
end

def downpage_mkdir(cluster_name)
  b = 'downpage'
  n = File.join(b,cluster_name) 
  Dir.mkdir(b) unless Kernel.test('d',b)
  Dir.mkdir(n) unless Kernel.test('d',n)
  n
end

def cluster_can_have_downpage?(c)
  if c.active? and c.load_balanced? then
      has_service = c.cluster_services.map {|s|
                    is_valid_service?(s.service) }.uniq
      if  has_service.member? true then
          return true
      end
  end
  return false
end

def is_valid_service?(s)
 return false if s.nil?
 if s.localport == 80
  puts "WARNING: Skipping service with localport 80 (id:#{s.service_id} #{s.name} - #{s.url} - #{s.service_port} - #{s.localport})"
 end
 (not s.nil?) and ['https','http'].member? s.ha_protocol and s.not_unique == 1 and s.localport != 80
end

def main
    clusters = find_clusters()
    puts clusters.inspect if $VERBOSE
    clusters.each {|c|
      write_nginx_config(c, "nginx","downpage")
    }
    puts "Creating Down page configs: #{clusters.length}" if $VERBOSE
end


def write_nginx_config(c, prefix, suffix )
  return unless cluster_can_have_downpage?(c)

  cluster_name =  c.cluster_name
  dir = downpage_mkdir(c.cluster_name)

  c.cluster_services.each {|s|
    svc = s.service
    # if a cluster has mixed services only generate
    # the apache config for the http[s]? services
    next unless is_valid_service?(svc)

    filename = "#{prefix}-#{cluster_name}-#{svc.localport}-#{suffix}"
    fn = File.join(dir,filename)
    puts "Write out file: #{fn} " if $VERBOSE
    File.open( fn,'w') do |io|
      io.puts \
"##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
#
#{version_string()}
#
# #{cluster_name}:#{svc.name} downpage
# #{c.description} on #{svc.url}
"
      root_dir = "/data/downpage"
      ssl_config = %Q(# SSL Settings
        ssl on;
        ssl_certificate         #{root_dir}/#{cluster_name}/ssl/#{svc.ha_hostname}.pem;
        ssl_certificate_key     #{root_dir}/#{cluster_name}/ssl/#{svc.ha_hostname}.pem;
        ssl_session_timeout     1m;
        ssl_protocols           SSLv3 TLSv1;
        ssl_ciphers             HIGH:!ADH:!MD5;
        ssl_prefer_server_ciphers   on;)
      io.puts %Q(
server {
        listen   #{svc.localport};

        root   #{root_dir}/#{cluster_name}/docroot;
        access_log  #{root_dir}/logs/#{cluster_name}-access.log;
        error_log  #{root_dir}/logs/#{cluster_name}-error.log;

        #{ssl_config if svc.ssl?}

        # Allow Maintenance Pages (down*)
        location ~* ^/down(.*).html$ {
           # CNU location awareness
           if ($server_name ~* ".nut." ) {
              set $cnu_location  "NUT";
           }
           if ($server_name ~* ".obr." ) {
              set $cnu_location  "OBR";
           }
           sub_filter_once on;
           sub_filter </body> '<div style="text-align:right" class="disclaimer">Service Location: $cnu_location</div></body>';
           break;
        }

        # JSON downpage support
        location ~* ^/down(.*).json$ {
          default_type application/json;
          break;
        }

        # Handle Lead Requests
        location ^~ /import {
                rewrite import.* /down_lead.html last;
        }

        # Handle images / javascript / sylesheets
        location ~* ^/(images|javascript|stylesheets|files|favicon.ico)(.*)$ {
                break;
        }

        # Handle everything else
        location / {

                index  index.html index.json;

                # Handle JSON
                if ($content_type ~* "/json") {
                  error_page 503 =503 /down.json;
                  return 503;
                }

                # Default response
                error_page 503 =503 /down.html;
                return 503;
         }
 }
)
    end
  }
end

main()
