#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class ServiceChecks

def ServiceChecks.supports_service_check?(ha_protocol)
  case ha_protocol
  when /http/ then true
  when /postgresql/ then true
  when /smtp/ then true
  when /name/ then true
  when /ldap/ then true
  when /xmpp/ then true
  when /piivr/ then true
  when /cassandra/ then true
  else false
  end 
end
def ServiceChecks.service_check_url(s)
  path = s.ha_protocol == 'name' ? '/example.com' : s.check_url_path
  "#{s.ha_protocol}://localhost:#{s.localport}#{path}"
end
def ServiceChecks.service_check_entry(s, is_state=false)
  if supports_service_check?(s.ha_protocol)
    entry = {}
    entry['Service Type'] = is_state ? 'state' : 'status'
    entry['Cluster Name'] = s.clusters.first.name
    entry['IP Address'] = s.ip_address.to_s
    entry['HA Port'] = s.ha_port
    entry['HA Proto'] = s.ha_protocol
    entry['Check URL'] = service_check_url(s)
    entry['Forward Mark'] = s.clusters.first.fw_mark
    entry
  end
end
def ServiceChecks.checks(node)
  entries = []
  node.clusters.each {|c| 
    if c.vlan < 4000 then
      c.services.each{ |s|
        if node.node_type.is_loadbalancer?
          entries << service_check_entry(s, true)
        else
          entries << service_check_entry(s)
        end
      }
    end
  }
  entries.compact.uniq
end
def ServiceChecks.write_service_check(node, array, file_postfix)
  return if array.nil? or array.empty?
  fn = output_fn(node.fn_prefix, file_postfix)
    File.open( fn,'w') do |io|
      io.write array.to_yaml 
    end
  "Write out file: #{fn}" 
end

public
def ServiceChecks.generate(filename)
    t = Time.now()
    nodes = Node.find_all_active
    cnt = 0
    nodes.each { |n|
      begin
        x = write_service_check(n, checks(n), filename)
        cnt = cnt + 1
      rescue Object =>e
        puts e
      end
    }
    puts "Creating service.checks.v2 #{cnt}" if $VERBOSE
    print_runtime(t,'service.checks.v2')
end

end   # class
end   # module
