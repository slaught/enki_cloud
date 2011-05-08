#!/usr/bin/ruby 


module CNU::Enki

class AsaRules

# access-list asdfasdf permit tcp any 209.60.186.0 255.255.255.0 eq 443
# so  to allow 443 everywhere:
# access-list asdfasdf permit icmp any 209.60.186.0 255.255.255.0 eq 443
# Subject: Firewall ACLs
# access-list asdfasdf extended permit tcp any host 209.60.186.17 eq 80
# access-list asdfasdf permit icmp any 209.60.186.0 255.255.255.0
LBSVC_FILE= "fw.acls" 

protected
def AsaRules.find_services
    services = []
    portfwd = []
    ClusterConfiguration.find(:all).each { |rec|
      if  rec.fw_mark.nil? or rec.ha_ip_address.nil? or rec.port.nil?  or rec.proto.nil? then
        next
      end
      a = [ rec.ha_ip_address , 
            rec.port , 
            rec.proto,
            rec.name
          ]
      if rec.ha_ip_address =~ /^209.60.186/ then
        services  <<  a.map {|e| e.to_s.strip() }
      end
  }
  [services.uniq]
end 
protected
def AsaRules.format(svc)
  prefix = "access-list outside-access-in" 
  svc.map{ |arr|
     haip = ip(arr[0])
     port = arr[1]
     proto = arr[2]
     name  = arr[3]
   %Q(#{prefix} remark ACL: #{name}\n#{prefix} extended permit #{proto} any #{haip} 255.255.255.255 eq #{port})
  }
end
protected
def AsaRules.write_lvscfg(fn, lb_data, pfw_data)
  # puts "Write out file: #{fn}"
  File.open( fn,'w') {|io|
      io.puts "
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
# Network Firewall rules for ASA 
# Syntax: access-list outside-access-in remark COMMENT HERE 
# Syntax: access-list outside-access-in extended permit PROTO any IP_ADDRESS # 255.255.255.255 eq PORT 
# "
      io.puts format(lb_data).join("\n")
  }
end

public
def AsaRules.generate(filename=LBSVC_FILE,directory='')
    t = Time.now()
    out_filename = Pathname.new(directory.to_s).join(filename).to_s
    svc, pfwd  = find_services()
    write_lvscfg(out_filename, svc, pfwd)
    print_runtime(t,'asa rules')
end

end

end
