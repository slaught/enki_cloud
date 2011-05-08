#!/usr/bin/ruby 

require 'network_nodes'

def main
    clusters = Cluster.find_all_active 
    #puts clusters.inspect 
    cnt = 0
    clusters.each {|c| 
      if c.active? and c.load_balanced?
        write_fwmark_cfg(c)
        cnt = cnt + 1
      end
    }
    puts "Creating lvs/ldirectord configs: #{cnt}" if $VERBOSE
end

def select_check_interval(c)
  cluster_name = c.cluster_name
  case cluster_name
  when /smtp/ then
    5
  else
    1
  end
end

def select_service_check(c)
  cluster_name = c.cluster_name

check_http  = %Q(\tservice=http
\tcheckport=80
\trequest="/status")

# dns check data
check_dns = %Q(\tservice=dns
\trequest="dns.#{domain_name}"
\treceive="10.10.10.13")

# ivr check
check_ivr = %Q(\tservice=simpletcp
\tcheckport=4573
\trequest="agi_network_script: ivr/dialup\\n\\n"
\treceive="GET VARIABLE")

check_ldap = %Q(\tservice=ldap)

check_smtp = %Q(\tservice=smtp)

# pick one
case cluster_name
when /dns/ then 
  check_dns
when /ldap/ then
  check_ldap
when /smtp/ then
  check_smtp
when /mail/ then
  check_smtp
else
  check_http
end
#if cluster_name =~ /dns/ then
#  service_check = check_dns 
#elsif cluster_name =~ /ldap/ then
#  service_check = check_ldap
#elsif cluster_name =~ /ivr/ then
###  service_check = check_ivr
#else
#  service_check = check_http
#end
#  service_check
end

def write_fwmark_cfg(c) 
  fwmark = c.fw_mark
  ips = c.node_ip_addresses
  return if ips.empty?
  fn = File.join('lvs', c.ldirectord_cfg_filename) 
  puts "Write out file: #{fn}" if $VERBOSE

  service_check = select_service_check(c)
  check_interval = select_check_interval(c)
  File.open( fn,'w') {|io|
      io.puts \
%Q(##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
# 
## '#{c.cluster_name}' cluster
## #{c.description } (##{fwmark})
autoreload = yes
fork=yes
# quiescent: keep persistant connections to real servers until timeout expires
quiescent=yes
virtual=#{fwmark} 
\t# Parameters
\tprotocol=fwm
\t#checkinterval: Number of seconds between checks
\tcheckinterval=#{check_interval}
\t#checktimeout: Number of seconds for ping response 
\tchecktimeout=2
\t# checktype: Do service negotiate every N ping attempts
\tchecktype=2
\t# negotiatetimeout: Number of seconds for service checks 
\tnegotiatetimeout=5
#{service_check}
\t# least weighted connection
\tscheduler=wlc  
\tfallback=#{dec2ip(fwmark)} gate
\t# Realservers
)
     # 
      ips.sort.uniq.each {|ip| io.puts "\treal=#{ip(ip)} ipip 100 " }
    io.puts "# end #{fwmark} #"
  }
# ## {c.cluster_name} cluster #
# ## {cluster_description} (\#{fw_mark})
# virtual={fw_mark}
# # one per node
# real={node_cluster_ip} gate {wieght:100}  
# ## OR
# real={node_cluster_ip} ipip {wieght:100} 
# real={node_cluster_ip} masq {wieght:100} 
# checktype=ping #  checktype = negotiate|connect|N|ping|off|on
# #service = ftp|smtp|http|pop|pops|nntp|imap|imaps|ldap|https|dns|mysql|pgsql|sip|none
# #check_port =
# scheduler=wlc  # rr, src_hash, dest_hash
# protocol=fwm   # should never change
# checktype=3
# callback=
# fallback=http://localhost:80
# 
end


main()
