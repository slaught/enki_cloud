#!/usr/bin/ruby

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
#$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

#$verbose = false
ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?

require 'config/environment'
load '/etc/cnu/keys/deployment-snmpv3.auth'
require 'snmpswitch'


def usage
  puts "set_snmp -Y auth.yml [host.loc] [-commit]"
  puts "  -commit pushes data to switch"
end

def main

  auth_cfg = ""

  unless defined? PROCURVE_USER and defined? PROCURVE_PASS
    puts "ERROR: Authorization information missing from /etc/cnu/keys/deployment-snmpv3.auth"
    return -1
  end

  if ARGV.include?("-Y")
    auth_cfg = ARGV[ARGV.index("-Y") + 1]
    ARGV.delete_at(ARGV.index("-Y") + 1)
    ARGV.delete("-Y")
  else
    usage()
    return -1
  end

  snmp_auths = YAML::load(File.open(auth_cfg))
  #puts snmp_auths.inspect
  switches = {}
  snmp_auths.each do |k, v|
    v[:user] = PROCURVE_USER
    v[:auth_pass] = PROCURVE_PASS
    v[:priv_pass] = PROCURVE_PASS
    switches[k] = HPSwitch.new(v)
  end
  #auth = {:user => "testuser", :auth_proto => "MD5", :auth_pass => "testtest", :sec_level => "authPriv", :priv_proto => "DES", :priv_pass => "testtest", :hostname => "testhost"}

  will_save = false

  if ARGV.include?("-commit")
    will_save = true
    ARGV.delete("-commit")
  end

  if ARGV.length < 1
    usage()
    return -9
  end

  #snmp = CSNMP.new(auth)
  #hp = HPSwitch.new(snmp)

  for n in ARGV
    if n.count(".") != 1
      puts "WARNING: Invalid Node (#{n}), skipping"
      next
    end
    parts = n.split(".")
    node = Node.find_by_name(parts[0], parts[1])
    puts "Processing #{node.to_label}"
    unless node.node_type.is_physical?
      puts "WARNING: Not a physical node, skipping"
      next
    end

    vlans = node.vlans

    node.network_switch_ports.each do |p|
      # Ghetto
      # Only apply to switches with "01" in name. Those are LAN.
      next if p.switch.to_label.index("02")

      sw = switches[p.switch.to_label]

      puts " Switch: #{p.switch.to_label}  Port: #{p.port}"
      old_vlans = sw.port_info(sw.port(p.port)).map{|v| v if v[2] == "TAGGED"}.compact
      puts "  Old Vlans: #{old_vlans.map{|v| v[0].to_i}.sort.join(', ')}"
      puts "  New Vlans: #{vlans.sort.join(', ')}"
      if sw.port_is_untagged?(sw.port(p.port)) == 1
        sw.clear(1, sw.port(p.port))
      end
      sw.vlans.each do |v|
        sw.forbid(v[0].to_i, sw.port(p.port))
      end
      vlans.each do |v|
        begin
          sw.tag(v, sw.port(p.port))
        rescue
          puts "ERROR: VLAN #{v} is not defined on target switch. Skipping..."
        end
      end
    end

    #puts node.network_switch_ports.map{|p| [p.switch.to_label, p.port]}
    #puts ""
    #puts node.vlans

  end

  if will_save
    puts "Saving VLAN data to switches. Please wait."
    switches.each do |k, s|
      s.save 
    end
  end

  #puts hp.port("A1")
end

main()
__END__
