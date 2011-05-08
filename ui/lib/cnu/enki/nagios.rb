#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class Nagios

public
def self.generate(directory)
      n = new()
      n.generate_servers(directory) 
      n.generate_ha_services(directory) 
      n.generate_hostgroups(directory)
      n.generate_cert_check(directory)
end

def nagiosize(s)
  s.gsub(/[-\/\s]+/,'-').downcase
end
def generate_hostgroups(directory)
   hostgroups = [] #  ['cnu-generic-host'] # default CNU hostgroup
  layout_items_with_timing('Nagios Hostgroups', Datacenter.all) do |dc|
    nodes = dc.nodes.active
      hostgroups.concat nodes.map { |node|
        nagios_hostgroups(node)
    }.compact.uniq
  end

  hostgroups.flatten.uniq.each { |hostgroup|
    puts "Generating Hostgroup: #{hostgroup}" if $VERBOSE
    write_file(directory, "hostgroup-#{hostgroup}", [layout_hostgroup(hostgroup)])
  }
end
def layout_hostgroup(hostgroup)

    %Q(define hostgroup{
\thostgroup_name          #{hostgroup}
\talias                   #{hostgroup}-group
}
define host{
\tuse                     generic-host
\tname                    #{hostgroup}-host
\thostgroups              #{hostgroup}
\tcontact_groups          all-pages, core-admins
\tcheck_command           return-ok
\tmax_check_attempts      4
\tnotification_interval   60
\tnotification_period     24x7
\tnotification_options    d,u,r
\tregister                0
})

end
def nagios_equipment_tag(node)
    if node.model.nil? or node.model.model_no.nil? then
      nil # 'generic-host'
    elsif  node.model.manufacturer == "CNU Xen Virtual Machine" then
      'virtual' # 'generic-virtual-domu'
    elsif node.model.model_no =~ /Database/ then
      "db-supermicro"
   else
     nagiosize(node.model.model_no)
   end
end
def nagios_cluster_name(node)
  if node.is_load_balancer? then
    return []
  end
  x = node.clusters.map { |c|  
      if c.cluster_name =~ /^(ca|jv|us|au|uk|aea|pi).+$/ or c.cluster_name =~ /^sol$/  then
          'app_node'
      elsif c.vlan < 101 then
        c.cluster_name.split(/_/).first + "_node"
      elsif c.cluster_name !~ /mgmt/ and c.cluster_name !~ /gen_int/ then
        if c.load_balanced? and c.active? then
          c.cluster_name
        else
          'generic-app'
        end
      else
        nil
      end
  }.compact.sort.uniq
  x
end
def nagios_hostgroups(node)
    groups = []
    e = nagios_equipment_tag(node)
    groups << e
    nt = nagiosize(node.node_type.name)
    groups << nt
    cl = nagios_cluster_name(node)
    groups.concat(cl)
    if node.node_type.is_physical? and node.hostname =~ /^xen/ then
        groups << "xen"
    end
    groups.compact.uniq
end
def generate_servers(directory)
  layout_items_with_timing('Nagios Servers', Datacenter.all) do |dc| 
      nodes = dc.nodes.active
      puts "Nodes: #{ nodes.length }" if $VERBOSE 
      data = nodes.map { |node| layout_define_host(node) }
      write_file(directory, "host-#{dc.name}", data)
  end
end
def layout_nagios_parent(node)
  if node.node_type.is_virtual? and not node.xen_domO.nil? then
     %Q(parents                 #{node.xen_domO.to_label}\n)
  else
     '' 
  end
end
def layout_define_host(node)
  %Q(define host{
        use               cnu-generic-host 
        hostgroups        #{nagios_hostgroups(node).join(", ")}
        host_name         #{node.fn_prefix} 
        alias             #{node.fn_prefix}
        address           #{node.fqdn}
        notes_url         https://somewhere.example.com/node/show/#{node.id}
        action_url        https://wiki.example.com/mediawiki/index.php/tech:Nagios_#{node.datacenter.name}_#{node.fn_prefix}
        #{layout_nagios_parent(node)}})
end
def generate_cert_check(directory)
  all_https_services = ClusterService.all.map{|cs| 
    if cs.service.ha_protocol == 'https' then
      cs.service
    else
      nil
    end
  }.compact
  all_services = all_https_services.map { |s| 
      if s.availability == 'public' then
        [ layout_cert_check(s), nil]
      elsif s.availability == 'campus' then
        [nil, layout_cert_check(s)]
      else
        [nil,nil]
      end
  }.transpose
 
  layout_items_with_timing("Nagios HTTPS Cert Checks", [1]) do |cluster_info|
      write_file(directory, "external_https_cert_checks", all_services.first.compact)
      write_file(directory, "internal_https_cert_checks", all_services.last.compact)
  end
end
def layout_cert_check(s)
  %Q(define service{
\thost_name               CERT-SERVICES
\tcontact_groups          all-pages, core-admins
\tnotes                   CRIT1
\tservice_description     #{service_desc(s)}-cert
\tis_volatile             0
\tcheck_period            24x7
\tmax_check_attempts      2
\tnormal_check_interval   1440
\tretry_check_interval    360
\tnotification_interval   1440
\tnotification_period     24x7
\tnotification_options    c,r
\taction_url              https://wiki.example.com/mediawiki/index.php/tech:Nagios_CERT-SERVICES
\tcheck_command\tcheck_https_cert!#{s.ha_hostname}
  }
)
end
def service_desc(s)
    case s.name
      when /fe$/ then s.name.sub(/fe$/,'frontend')
      else s.name
    end
end
def generate_ha_services(directory)
  all_active_services = ClusterService.all.map{|cs| 
    if supports_ha_protocol?(cs.service.ha_protocol) then
      cs.service
    else
      nil
    end
  }.compact
  all_services = all_active_services.map { |s| 
      if s.availability == 'public' then
        [ layout_service_check(s), nil]
      elsif s.availability == 'campus' then
        [nil, layout_service_check(s)]
      else
        [nil,nil]
      end
  }.transpose
 
  layout_items_with_timing("Nagios HA Services", [1]) do |cluster_info|
      write_file(directory, "external_ha_service_checks", all_services.first.compact)
      write_file(directory, "internal_ha_service_checks", all_services.last.compact)
  end
end
def layout_service_unique(s)
  if ['http', 'https','postgresql', 'xmpp'].member? s.ha_protocol and 
    not [80,443,5432].member? s.ha_port then
      "-#{s.ha_port}"
  else
      ''
  end
end
def layout_service_check(s )
#     check_command           check_HA_http!%HA_IP%!%PORT%!%FQDN HOSTNAME%!%URL_PATH%        
  %Q(define service{
\thost_name               HA-SERVICES
\tcontact_groups          all-pages, core-admins
\tservice_description     #{service_desc(s)}-#{s.ha_protocol}#{layout_service_unique(s)}
\tis_volatile             0
\tcheck_period            24x7
\tmax_check_attempts      3
\tnormal_check_interval   5
\tretry_check_interval    1
\tnotification_interval   60
\tnotification_period     24x7
\tnotification_options    c,r
\taction_url              https://wiki.example.com/mediawiki/index.php/tech:Nagios_HA-SERVICES
\tnotes_url               https://somewhere.example.com/service/show/#{s.id}
\tcheck_command\tcheck_HA_#{s.ha_protocol}!#{s.ip_address}!#{s.ha_port}!#{s.ha_hostname}!#{s.check_url_path}
  }
)
end
def supports_ha_protocol?(ha_protocol)
  # Support http/https , postgresql, ldap/ldaps, xmpp
  case ha_protocol
  when /http/ then true
  when /postgresql/ then true
  when /smtp/ then false
  when /name/ then false
  when /ldap/ then true
  when /xmpp/ then true
  else false
  end 
end
def write_file(directory, filename, data)
  return false if data.nil? or data.empty?
  fn = output_fn(directory, "#{filename}.cfg") 

  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') do |io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
##################################################################
# 
#{version_string()} 
# nagios:/etc/nagios/generated/#{filename}.cfg
#
"
    io.puts data.join("\n")
  end
  true
end
end
end # end module
