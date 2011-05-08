#!/usr/bin/ruby 

require 'network_nodes'

def main
    clusters = Cluster.find_all_active 
    x = {}
    lvs_cluster_info = clusters.map { |c|
      name = c.cluster_name
      if name =~ /^(ca|jv|us|au|uk|aea|pi|lay).+$/ and c.vlan < 4000 then
         c.nodes.map{|n| 
          next if x.member? n.hostname
          next unless n.is_server?
          y = generate_space(n) 
          x[y[0]] = y[1]
          }
      end
    }
    write_file(x ,"space_")
end

def generate_space(node)
  h = {}
  node.clusters.each { |c| h[c.vlan.to_i] = c.ip_address }
  [node.hostname, ip(h[ h.keys.sort.first ]) ]
end

def write_file(array, tmpl) 
  #puts array.inspect
  return if array.nil? or array.empty?
  Dir.mkdir('space') unless File.directory?('space')
  cnt = 0
  array.each { |hostname, ip|
    puts "space: #{hostname} with #{ip}" if $VERBOSE
    fn = File.join('space', tmpl + hostname + '.yml')
    puts "Write out file: #{fn}" if $VERBOSE
    File.open( fn,'w') do |io|
      io.puts "space:\n  bind_address: druby://#{ip}:0\n"
    end
    cnt = cnt + 1
  }
  puts "Wrote space nodes: #{cnt}/#{array.length}" if $VERBOSE
end

main()

__END__
