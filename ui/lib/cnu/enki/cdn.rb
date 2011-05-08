#!/usr/bin/ruby 

module CNU::Enki

class Cdn

protected
def Cdn.mkdir(cluster_name, dir_name)
  b = dir_name
  n = File.join(b,cluster_name) 
  Dir.mkdir(b) unless Kernel.test('d',b)
  Dir.mkdir(n) unless Kernel.test('d',n)
  n
end

def Cdn.is_valid_service?(s)
 return false if s.nil?
 if s.localport == 80
  puts "WARNING: Skipping service with localport 80 (id:#{s.service_id} #{s.name} - #{s.url} - #{s.service_port} - #{s.localport})"
 end
 (not s.nil?) and ['https','http'].member? s.ha_protocol and s.not_unique == 1 and s.localport != 80
end

def Cdn.write_nginx_config(service, prefix, dir_name)
  return unless is_valid_service? service

  hostname_pieces = service.ha_hostname.split("cdn.")
  return if hostname_pieces.count != 2
  short_hostname = hostname_pieces[1]
  dir = mkdir(short_hostname, dir_name)

  filename = "nginx-#{prefix}-#{short_hostname}-#{service.localport}"
  fn = File.join(dir,filename)
  File.open(fn, 'w') do |io|
    io.puts \
"##################################################################
########       THIS FILE WAS AUTOMATICALLY GENERATED     #########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
#
#{version_string()}
#
# #{service.description} Nginx Config
# #{service.url}
"
      root_dir = "/data/static_content"
      ssl_config = %Q(# SSL Settings
        ssl on;
        ssl_certificate         #{root_dir}/#{short_hostname}/ssl/wildcard.cdn.#{short_hostname}.pem;
        ssl_certificate_key     #{root_dir}/#{short_hostname}/ssl/wildcard.cdn.#{short_hostname}.pem;
        ssl_session_timeout     1m;
        ssl_protocols           SSLv3 TLSv1;
        ssl_ciphers             HIGH:!ADH:!MD5;
        ssl_prefer_server_ciphers   on;)
      io.puts %Q(
server {
        listen   #{service.localport};
        access_log  /var/log/nginx/cdn-#{short_hostname}_access.log;
        error_log  /var/log/nginx/cdn-#{short_hostname}_error.log;

        #{ssl_config if service.ssl?}

        # Enable gzip compression
        gzip on;
        gzip_types      text/plain text/html
                        application/xml
                        text/css
                        application/x-javascript
                        text/javascript
                        text/xml;
        gzip_min_length 1000;
        gzip_comp_level 9;
        gzip_buffers    16 8k;

        # Set content expiration
        expires 1d;

        # Allow status page (ping)
        location /ping {
          root  #{root_dir}/#{short_hostname};
        }

        # Site Static Content
        location / {
          root   #{root_dir}/#{short_hostname}/docroot;

          # If a file exists locally serve it
          try_files $uri @redirect;
        }

        location @redirect {
          rewrite ^/(.*) #{service.ssl? ? 'https' : 'http'}://www.#{short_hostname}/$1 permanent;
          break;
        }
    }
)
    end
end
public
  def Cdn.generate(filename,directory='')
    t = Time.now()

    services = Service.find(:all, :conditions => ["name LIKE ?", "%cdn%"])
    puts services.inspect if $VERBOSE
    services.each {|s|
      write_nginx_config(s, filename, directory)
    }

    print_runtime(t,'CDN Nginx Configs')
  end

end

end
