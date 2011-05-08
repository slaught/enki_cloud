#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class SshKnownHosts
@@runtime_label = 'SSH Host List'
public
def self.generate(dir)
    t = Time.now()
    new().generate(dir) 
    print_runtime(t,@@runtime_label)
end
def candidates()
    obrnodes = Node.find_all_active_by_datacenter(Datacenter.obr) 
    nutnodes  = Node.find_all_active_by_datacenter(Datacenter.nut) 
    [obrnodes, nutnodes].flatten
end
def per_item(n)
    begin 
    if n.node_type.can_has_sshd? then
      case n.hostname 
      when /^(us|ca|jv|uk|ccm|au|postgres|xen)\d+/ then
          [ip(n.mgmt_ip_address), n.fn_prefix, n.fqdn ] 
      else
        nil
      end
    else
      nil
    end
    rescue Object => e
      puts "Failure: #{n.fn_prefix}"
      puts e
      []
    end
end
def fn_knownhost()
    'ssh_known_hosts.lst'
end
def generate(dir)
    items = candidates()
    data = items.map { |item|  per_item(item) }.flatten.compact
    write_file(dir, fn_knownhost(), data)
    puts "Creating #{fn_knownhost}"  if $VERBOSE
end
def write_file(dir, file, data)
  mkdir_p(dir) unless Kernel.test('d', dir)
  fn = File.join(dir,file)
  File.open(fn, 'w') {|io|
    io.puts data.join("\n")
  }
end

end #end class
end # end module
