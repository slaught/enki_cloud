#!/usr/bin/ruby

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
#$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

$verbose = false
ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?

require 'config/environment'

def node(id,label,color, style, shape,extra={})
  e = extra.map{|k,v| %Q(#{k}="#{v}") }.join(", ")
  if e.to_s.length > 0 then
    e = ", " + e
  end
  %Q("#{id}" [label="#{label}", color="#{color}",style="#{style}",shape="#{shape}" #{e}];)
end

def root_node(cluster)
  node("cluster_#{cluster.cluster_id}", cluster.name, "#ff0000", "filled", "tripleoctagon",
    {"area" => "test", "fontsize" => 30})
end

def physical_node(host)
  node("node_#{host.node_id}", host.to_label, "orange", "filled",
    "hexagon", {"fontsize" => 20})
end

def service_node(service)
  node("service_#{service.service_id}", "#{service.name}-#{service.url}", "yellow", "filled", 
    "doubleoctagon", {"margin" => ".11,.11", "fontsize" => 24})
end

def host_node(host)
  node("node_#{host.node_id}", host.to_label, "green", "filled",
    "hexagon", {"fontsize" => 20})
end

def pdu_node(pdu)
  node("node_#{pdu.node_id}", pdu.to_label, "pink", "filled", "box", {"fontsize" => 20})
end

def link(src, dst, color, arrow = "none", label = nil)
  unless label.nil? then
    label = %Q(, label="#{label}")
  end
  %Q("#{src}" -> "#{dst}" [color="#{color}", arrowhead="#{arrow}"#{label}];)
end

def pdu_link(pdu)
  link("node_#{pdu.node.node_id}", "node_#{pdu.pdu.node_id}", "pink", nil, "Outlet: #{pdu.outlet_no}")
end

def cluster_service_link(cluster, service)
  link("cluster_#{cluster.cluster_id}", "service_#{service.service_id}", "blue")
end

def service_host_link(service, host)
  link("service_#{service.service_id}", "node_#{host.node_id}", "green", "dot")
end

def host_dom0_link(host, dom0)
  link("node_#{host.node_id}", "node_#{dom0.node_id}", "black")
end

def service_dependency_link(service, dependency)
  link("service_#{service.service_id}", "service_#{dependency.service_id}", "red")
end

def process_node(node)
  nodes = []

  if node.node_type.is_virtual?
    nodes << host_node(node)
    dom0 = XenMapping.find_by_guest_id(node.node_id).host
    nodes << [process_node(dom0), host_dom0_link(node, dom0)]
  else
    nodes << physical_node(node)
    nodes << node.pdus.map { |p| [pdu_node(p.pdu), pdu_link(p)] }
  end
  nodes
end

def process_cluster_nodes(cluster)
  nodes = Set.new
  for n in cluster.nodes
    nodes << [process_node(n), cluster.services.map { |s| service_host_link(s, n) }]
  end
  nodes.to_a
end

def process_service(service, level = 1)
  services = []
  services << service_node(service)
  if level > 1
    for c in service.clusters
      for n in c.nodes
        services << process_node(n)
        services << service_host_link(service, n) 
      end
    end
  end
  unless service.depends_on.empty?
    for s in service.depends_on
      services << process_service(s, level + 1)
      services << service_dependency_link(service, s)
    end
  end
  services
end

def process_cluster(cluster)
  services = []
  nodes = process_cluster_nodes(cluster)
  for s in cluster.services
    services << [process_service(s), cluster_service_link(cluster, s)]
  end
  [services, nodes]
end

def print_graph(data, cluster)
  case data
    when Array  
      d = data.flatten.compact.join("\n")
    when String
      d = data
    else
      puts "//Unknown data type #{data.class}"
      exit -9
   end

puts %Q(digraph G {
  ranksep=1;
  overlap=scale;
  //overlap=false;
  ratio=auto;
  root=cluster_#{cluster.cluster_id};
  splines=false; 
  // mindist=0.01;
  //rotate=90; 
  size="128,128"  ; 
  // dpi=200;
  // page="8.5,11";
  // margin=0.25;
/*
   overlap=mode. This specifies what twopi should do if any nodes overlap.
If mode is "false", the program uses Voronoi diagrams to adjust the nodes to eliminate overlaps. 
If mode is "scale", the layout is uniformly scaled up,  preserving  node  sizes,
         until nodes no longer overlap. The latter technique removes overlaps while preserving symmetry and
       structure, while the former removes overlaps more compactly  but
destroys  symmetries.   
  If  mode  is  "true"  (the default), no repositioning is done.
*/
  // node [fontsize="6", margin="0,0", height=".25", width=".25" ] // fontname="Helvetica"
  node [margin="0,0", height=".25",width=".25"]
  #{d}  
}
)
end

def main
  if ARGV.length < 1
    puts "Usage gen_graph.rb cluster_id"
  else
    cluster_id = ARGV[0]
  #cluster_id = 178
    c = Cluster.find cluster_id
    o = [ root_node(c), process_cluster(c) ]
    print_graph(o, c)
  end
end


main()
__END__
