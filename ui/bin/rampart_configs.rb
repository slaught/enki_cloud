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

def usage()
  puts "rampart_configs.rb [node_name (eg bruce.nav) OR node_id]"
end

def rampart_line(service, proto_override=nil)
  l = [
    [:nat_type, nil],
    [:source_ip, nil],
    [:source_port, nil],
    [:protocol, nil],
    [:mid_ip, nil],
    [:mid_port, nil],
    [:dest_ip, nil]
  ]

  if service.direction =~ /out/i
    l.assoc(:nat_type)[1] = 'SNAT'
    l.assoc(:source_ip)[1] = service.rampart.network_ip.blank? ? "$NODE_IP" : cidr(service.rampart.network_ip)
    l.assoc(:mid_ip)[1] = cidr(service.network)
    if is_on_private_range?(service.network)
      l.assoc(:dest_ip)[1] = service.rampart.locale_ip_address.nil? ? "$LOCALE_IP" : service.rampart.locale_ip_address.to_s
    else
      l.assoc(:dest_ip)[1] = '$NAT_IP'
    end
  elsif service.direction =~ /in/i
    l.assoc(:nat_type)[1] = 'DNAT'
    l.assoc(:mid_ip)[1] = service.rampart.locale_ip_address.nil? ? "$LOCALE_IP" : cidr(service.rampart.locale_ip_address.to_s)
    l.assoc(:dest_ip)[1] = service.rampart.network_ip.blank? ? "$NODE_IP" : service.rampart.network_ip
    l << [:dest_port, service.port]
  else
    return ""
  end
  l.assoc(:protocol)[1] = proto_override || (service.protocol =~ /all/i ? nil : service.protocol)
  l.assoc(:mid_port)[1] = service.port
  "\t\"#{l.map{|key, value| value}.join(':')}\"\t#{rampart_service_comment service}"
end

def rampart_service_comment(service)
  if service.direction =~ /out/i
    "# #{service.rampart.node.to_label} (locale) -> #{service.description}"
  elsif service.direction =~ /in/i
    "# #{service.description} -> #{service.rampart.node.to_label}"
  end
end

def rampart_lines(rampart)
  output = []

  # most specific DNAT netmasks first, then most specific SNAT netmasks first
  dnat_services = rampart.rampart_services.select{|s| s.direction =~ /in/i}
  snat_services = rampart.rampart_services.select{|s| s.direction =~ /out/i}
  services = dnat_services.sort_by{|s| prefix_size(s.network)}.reverse
  services << snat_services.sort_by{|s| prefix_size(s.network)}.reverse
  services.flatten!

  services.each{|s|
    # Explicitly create a tcp and udp service when proto~'all' and a port is specified
    if s.protocol =~ /all/i and s.port
      output << rampart_line(s, 'tcp')
      output << rampart_line(s, 'udp')
    else
      output << rampart_line(s)
    end
  }
  output.join("\n")
end

def print_all_rampart_services
  Rampart.all.sort_by{|r| r.node.to_label}.select{|r| not r.rampart_services.blank?}.each{|r|
    puts rampart_lines(r) + "\n\n"
  }
end

def main()
  if ARGV.length != 0 and ARGV.length != 1
    usage()
    return 2
  end

  if ARGV.length == 0
    # print services for all ramparts...
    print_all_rampart_services
  else
    if ARGV[0] =~ /^\d+$/
      rampart = Rampart.all.detect{|r| r.id == ARGV[0].to_i}
    else
      rampart = Rampart.all.detect{|r| r.node.to_label == ARGV[0]}
    end
    if rampart.blank?
      puts "Couldn't find rampart with node name or id #{ARGV[0]}!"
      return
    else
      puts rampart_lines(rampart)
    end
  end
end

# determines if IP is in the 10.0.0.0/8, 192.168.0.0/16 or 172.16.0.0/12 private ranges
def is_on_private_range?(i)
  ipaddr = IPAddr.new(i)

  if IPAddr.new('10.0.0.0/8').include?(ipaddr) or IPAddr.new('192.168.0.0/16').include?(ipaddr)\
    or IPAddr.new('172.16.0.0/12').include?(ipaddr)
    true
  else
    false
  end
end

# given an IP (string) returns IP (string) with format <#.#.#.#/#> (Appends '/32' if prefix size not present)
def cidr(i)
  i.split('/')[1].nil? ? i+'/32' : i
end


# returns the prefix size (int) of an ip address (string) with format <#.#.#.#/#>
def prefix_size(i)
  prefix = i.split('/')[1]
  prefix.nil? ? 32 : prefix.to_i
end




main()
__END__

