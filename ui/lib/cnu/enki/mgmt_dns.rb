#!/usr/bin/ruby 

module CNU::Enki

class DnsServer
  def initialize(netrange='172.23.0.0')
    @domains = Hash.new()
    @networks = Hash.new
    @network_range = netrange
  end
  # TODO: generalize this in the future def add_network(fqdn, ipaddr) # assume @network_range. but in the future. calculate
  # from the ipaddress
  def add_network(fqdn,ipaddr)
    return nil unless ipaddr.to_s =~ /^172.23./
    (@networks[@network_range] ||= Array.new) << [fqdn, ipaddr] 
  end
  def add_subdomain(fqdn,ipaddr)
      sub = find_subdomain(fqdn) 
      (@domains[sub] ||= Array.new) << [fqdn, ipaddr]
  end
  def find_subdomain(f)
    f.split('.',2).last  # chop off first word
  end
  def add(fqdn, ipaddr)
      add_subdomain(fqdn,ipaddr) 
      add_network(fqdn,ipaddr)
  end
  def inspect
    %Q(#{@networks[@network_range].length}
     #{@domains.keys.inspect}
     #{@domains.keys.map{|x| @domains[x].length}.inspect}
      ) 
  end
  def networks(&block)
    _keys_or_block(@networks, block)
  end
  def subdomains(&block)
    _keys_or_block(@domains, block)
  end
  def _keys_or_block(datahash, block)
    if block.nil? 
      datahash.keys
    else
      datahash.keys.each {|key| 
          block.call(key, datahash[key]) 
      }
    end
  end
  def reverse_ip(ip)
    ip.to_s.split('.').reverse.join('.')
  end 
  def rev_record(rec)
     prefix = ''
     prefix = ';' if rec.second.nil? 
     "#{prefix}#{reverse_ip(rec.second)}.IN-ADDR.ARPA. IN  PTR  #{rec.first}."
  end
  def forward_record(rec)
     prefix = ''
     prefix = ';' if rec.second.nil? 
     "#{prefix}#{rec.first}.  IN A #{rec.second.to_s}"
  end
end

class MgmtDns
  extend CNU::IpManipulation
public
  def MgmtDns.generate(filename,directory='')
    t = Time.now()
    out_filename = Pathname.new(directory.to_s).join(filename).to_s

    dns = DnsServer.new
    nodes = Node.all.sort {|n1, n2| n1.mgmt_ip_address.to_i <=> n2.mgmt_ip_address.to_i }.map do |n|
            dns.add(n.fqdn, n.mgmt_ip_address)
    end

    dns.subdomains do |domain,records|
      write_dns_file("#{out_filename}.#{domain}", 
              records.map{|rec| dns.forward_record(rec) }.sort,
              domain+'.')
    end
    dns.networks {|net,nodes| 
      rev_lines = nodes.map{|rec| dns.rev_record(rec) }
      write_dns_file("#{out_filename}.#{net}.rev", rev_lines, '@')
    }
    print_runtime(t,'Mgmt DNS')
  end

end

end
