#!/usr/bin/ruby

require 'yaml'
require 'pp'

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
#$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

$verbose = false
ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?
require 'config/environment'

xens = YAML::load( STDIN.read )

#LiveXenMap.delete_all

xens.each do |k,v|
  unless k.nil?
    n = k.split(".")
    next if n.length == 1
    node = Node.find_by_name(n[0], n[1])
    unless node.nil?
      puts "#{node.hostname} : #{node.node_type.node_type}"
      #node.live_xen_guests.delete_all
      unless v.nil?
        v.each do |domu|
          d = domu.split(".")
          if d.length > 1
            domu_node = Node.find_by_name(d[0], d[1])
            unless domu_node.nil?
              puts "  -#{domu_node.hostname} : #{domu_node.node_type.node_type}"
              domu_node.live_xen_host.delete unless domu_node.live_xen_host.nil? or domu_node.live_xen_host == node
              puts "creating map for #{node.node_id} and #{domu_node.node_id}"
              LiveXenMap.create({:host_id => node.node_id, :client_id => domu_node.node_id, :client_name => domu})
            else
              puts "DomU does not exist in CFG DB..."
              exists = LiveXenMap.find_by_host_id_and_client_name(node.node_id, domu)
              if exists.nil?
                LiveXenMap.create({:host_id => node.node_id, :client_name => domu})
              end
            end
          end
        end
      end
      Rcache.clear("#{node.to_label}-mapping-table")
    else
      STDERR.puts "WARNING: '#{k}' node not found"
    end
  end
end


