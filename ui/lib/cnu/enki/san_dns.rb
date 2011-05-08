#!/usr/bin/ruby 

module CNU::Enki

class SanDns 

SUBDOMAIN='san.example.com.'

protected
def SanDns.san_dns(node)
    node.san_interfaces.map{ |s|
       "#{s.first}.#{node.fn_prefix}.san.example.com.  IN A #{s.last}"
    }
end

# 2.23.168.192.IN-ADDR.ARPA.
# 2             IN      PTR     joe.example.com. ; FDQN
def SanDns.san_ptr(node)
    node.san_interfaces.map { |s|
       "#{reverse_ip(s.last)}.IN-ADDR.ARPA.  IN PTR #{s.first}.#{node.fn_prefix}.#{SUBDOMAIN}"
    }
end

protected
def SanDns.find_node_names 
    nodes = SanNode.find(:all)
    nodes.map {|sn|  san_dns(sn.node) }.flatten.uniq
end 
def SanDns.find_san_networks
    sans = San.find(:all)
    address = sans.map do  |san|
      ptr_dns = san.san_nodes.map {|sn| san_ptr(sn.node) }.flatten.uniq
      [ip(san.ip_range), ptr_dns]
    end
    address 
end
def SanDns.serial_num()
   now = DateTime.now() 
   now.strftime("%Y%m%d#{'%02d' % (4 * now.hour()).to_s}")
end

public
def SanDns.generate(filename,directory='')
    t = Time.now()
    out_filename = Pathname.new(directory.to_s).join(filename).to_s

    addr_dns= find_node_names()
    write_dns_file(out_filename + ('.'+SUBDOMAIN).chomp('.') , addr_dns, SUBDOMAIN)
    networks = find_san_networks()
    networks.each { |ipnet, nodes|
      write_dns_file(out_filename + ".#{ipnet}.rev",  nodes, '@')
    }
    print_runtime(t,'San DNS')
end

end

end
