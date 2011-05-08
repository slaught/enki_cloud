#!/usr/bin/ruby 

require 'network_nodes'

def supports_service_check?(ha_protocol)
  case ha_protocol
  when /http/ then true
  when /postgresql/ then false
  when /smtp/ then false
  when /name/ then false
  when /ldap/ then false
  when /xmpp/ then false
  when /piivr/ then true
  else false
  end 
end
def service_check_line(s)
  if supports_service_check?(s.ha_protocol)
    "#{s.ha_protocol}://localhost:#{s.localport}#{s.check_url_path}"
  end
end
def checks(node)
  node.clusters.map {|c| 
    if c.vlan < 4000 then
      c.services.map {|s| service_check_line(s) } 
    end
  }.flatten.compact.uniq
end
def main
    nodes = Node.find_all_active
    cnt = 0
    nodes.each { |n|
      begin
        x = write_service_check(n, checks(n))
        cnt = cnt + 1
      rescue Object =>e
        puts e
      end
    }
    puts "Creating service.checks #{cnt}" if $VERBOSE
end
def write_service_check(node, array) 
  return if array.nil? or array.empty?
  fn = output_fn(node.fn_prefix, "service.checks")
    File.open( fn,'w') do |io|
      io.puts array.join("\n") 
    end
  "Write out file: #{fn}" 
end

main()
__END__
