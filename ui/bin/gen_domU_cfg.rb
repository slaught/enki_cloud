#!/usr/bin/ruby 

require 'network_nodes'

def console(os_version)
  if os_version.id == 8 then 
     'xencons=tty'
  else
     ''
 end
end

def cpu_ram(model)
  
end

def process_nodes
    nodes = {}
    cnt = 0
    built = 0
    Node.find(:all, :conditions => ['node_type_id = 2']).each {|n|
      puts "Building #{n.to_label}" if $VERBOSE
      begin
      if n.os_version.blank?
        puts "Skipping #{n.to_label} because an OS is not defined!"
        next
      end
      cnt = cnt + 1
      
#      # HACK: FIXME: This is for webjv nodes running newer kernel on older
#      # distro
#      if n.os_version_id == 8 then 
#        console = 'xencons=tty'
#      else
#        console = ''
#      end
      if n.model.nil? then
        memory = 4096
        cpus = 2
      else
        memory = n.model.ram
        cpus = n.model.cpu_cores
      end
      raise "Node has no management ip address!" if n.mgmt_ip_address.nil?
      cfg_str = domU_xen_cfg(n, n.mgmt_ip_address, n.os_version)

      vifs= {}
      n.create_virtual_nics() 
      assigned_domO_nics = []
      n.nics.each {|nic|
        vlan = nic.port_name.match(/eth(\d+)/)[1]
        # vifs[vlan.to_i] = gen_vif_line(nic, vlan, nic.mac_address)
        if nic.lan?
          vifs[vlan.to_i] = gen_lan_vif_line(nic, vlan)
        elsif nic.san?
          vifs[vlan.to_i] = gen_san_vif_line(n, nic, vlan, assigned_domO_nics)
        else
          raise "Nic #{nic.port_name} has unknown network type!"
        end
      }
      vif_lines = sorted_hash_value_string(vifs,",\n")
      ifaces = {}
      #
      # interfaces for extra line
      cns  = n.cluster_nodes.map {|cn| [cn.cluster.vlan.to_i, cn.ip_address] }.sort
      gen_gw = true
      begin
      max_vlan = cns.map{|x| x[0] }.select{|y| y < 4000 }.max
      gw_vlan  = cns.map{|x| x[0] }.select{|y| y < 4000 }.min 
      if max_vlan.to_i > 200 then
         gw_vlan = max_vlan
      end
      cns.each { |cn|
        if cn[0] != 4000 then
          if cn[0] == gw_vlan then
              gen_gw = true
          else
              gen_gw = false
          end
          l = gen_iface_line(cn[0], cn[1], gen_gw)
          ifaces[cn[0].to_i] = l
        end
      }
      rescue Object => ex
          puts ex
          puts ex.backtrace
      end
      extra_interfaces = sorted_hash_value_string(ifaces, ' ')
      disks = gen_disks_line(n)
      nodes[n.fn_prefix] = eval( '"' + cfg_str + '"', binding() ) #extra_interfaces, vif_lines)
      built = built + 1
      rescue Object => e
        puts "Warning: can't create #{n.fn_prefix} config: #{e.to_s}"
      end
    }
  puts "Creating domU nodes: #{built}/#{cnt}" if $VERBOSE
  nodes
end 
#def ip(i)
#   i.split('/')[0]
#end
#def gw(ip)
#   ip(ip).sub(/\.\d+$/,'.1')
#end
#def eval_data(data, extra_interfaces, vif_lines)
#    puts data.inspect
#    d = eval( '"' + data + '"' , binding )
##    puts d.inspect
#end
def gen_disks_line(n)
  node_disks = []
  if n.disks.length > 0 then
     node_disks = n.node_disks.sort.map{|x| x.xen_name }
  else
    if n.only_supports_ide?
      node_disks << "file:/xen/domains/#{n.hostname}/disk.img,hda1,w"
    else
      node_disks << "file:/xen/domains/#{n.hostname}/disk.img,sda1,w"
    end
  end
  node_disks.map { |x| "               '#{x}'" }.join(",\n")
end
def gen_iface_line(vlan0, ipaddr, gen_gw)
    ip0 = ip(ipaddr)
    gw0 = gw(ipaddr)
    nm0 = netmask(ipaddr)
    if vlan0 == 4000 then
      ""
    elsif gen_gw
      "iface#{vlan0}=#{ip0}:#{nm0}:#{gw0}"
    else 
      "iface#{vlan0}=#{ip0}:#{nm0}"
    end
end
def sorted_hash_value_string(m, joiner="\n")
  keys = m.keys().sort
  tmp = []
  for i in keys do
    tmp << m[i]
  end
  tmp.join(joiner)
end
#def gen_vif_lines(vifs)
#  keys = vifs.keys().sort
#  tmp = []
#
#  for i in keys do
#    tmp << vifs[i]
#  end
#  tmp.join('\n')
#end
def gen_san_vif_line(node, nic, vlan, assigned_domO_nics)
  domO_nic = (node.xen_domO.san_nics - assigned_domO_nics).first
  assigned_domO_nics << domO_nic
  vlan = domO_nic.port_name.match(/eth(\d+)/)[1]
  "              'mac=#{nic.mac_address}, bridge=xenbreth#{vlan}, script=network-bridge-vlan netdev=eth#{vlan}'"
end
def gen_lan_vif_line(nic, vlan)
  "              'mac=#{nic.mac_address}, bridge=xenbr#{vlan}'"
end

def last_update_string(node)
if node.versions.exists? then
  last_version = node.versions.last
  if not last_version.version_user.blank? then
    return "(Last changed on #{last_version.created_at} by #{last_version.version_user.login})"
  else
    return "(Last changed on #{last_version.created_at})"
  end
else
  return "(Last changed on August 2009 by cslaughter)"
end
end

def kernel_lines(os_version)
  if os_version.hvm_only?
"kernel  = '/usr/lib/xen-3.2-1/boot/hvmloader'
device_model = '/usr/lib/xen-3.2-1/bin/qemu-dm'
builder = 'hvm'"
  else
"kernel  = '/xen/boot/kernel/#{os_version.kernel}/vmlinuz-#{os_version.kernel}'
ramdisk = '/xen/boot/kernel/#{os_version.kernel}/initrd.img-#{os_version.kernel}'"
  end
end

def root_string(os_version)
  if os_version.hvm_only?
    "boot    = 'c'"
  else
    "root    = '/dev/sda1 ro'"
  end
end

def domU_xen_cfg(node , mgmt_ip_address, os, console='')
return "##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
#
#
#  Configuration file for the Xen instance #{node.fn_prefix}
#  #{last_update_string(node)}
#

# Kernel # these will change at some point
#{kernel_lines(os)}

# Memory Size (in MB)
memory  = '\#{memory}'

# Number of CPUs
vcpus = '\#{cpus}'
#{if os.hvm_only?
"
#pae=0
#acpi=0
#apic=0
"
end}
#  Default Behaviour
on_poweroff = 'destroy'
on_reboot   = 'restart'
on_crash    = 'restart'
#
#  Disk device(s).
#{root_string(os)}
disk    = [
\#{disks} 
          ]

#  Hostname
name    = '#{node.fn_prefix}'

#  Networking
#  Note: Make sure the vif order and the extra line order MATCH!
vif  = [
\#{vif_lines}
       ]
#{if os.hvm_only?
"
vnc=0
vncviewer=0
serial='pty'
ne2000=0
"
end}
# CashNetUSA configuration
extra=\\\"\#{extra_interfaces} iface4000=#{ip(mgmt_ip_address)}:255.255.254.0 fqdn=#{node.fqdn} #{console(os)}\\\"
"

# UTC
# locatime = 1
# builder ( linux|hvm)
# builder = linux

end
def write_domU(hostname, data) 
  Dir.mkdir('xen') unless File.directory?('xen')
  fn = "xen/#{hostname}.domU.cfg" 
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') {|io|
    io.puts data
  }
  return if true
end

def main
    data = process_nodes
    cnt = 0
    data.each {|k,v|
      write_domU(k,v)
      cnt = cnt + 1
    }
    puts "Wrote out domU.cfg #{cnt}/#{data.keys().length}" if $VERBOSE
end

main()


__END__
"##################################################################
#########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
#########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
## 
########  autogenerated on #{   ()} by #{$0} 
#
#
#  Configuration file for the Xen instance us01.dc1
#

# Kernel # these will change at some point
kernel  = '/boot/vmlinuz-2.6.18-4-xen-686'
ramdisk = '/boot/initrd.img-2.6.18-4-xen-686'

# Memory Size (in MB)
memory  = '4096'

# Number of CPUs
vcpus = '2'

#  Disk device(s).
root    = '/dev/sda1 ro'
disk    = [
               'file:/xen/domains/#{hostname}/disk.img,sda1,w'
          ]

#  Hostname
name    = '#{hostname}.dc1'

#  Networking
vif  = [

                'mac=#{mac0}, bridge=xenbr#{vlan0}',
                'mac=#{mac1}, bridge=xenbr#{vlan1}'
       ]

#  Default Behaviour
on_poweroff = 'destroy'
on_reboot   = 'restart'
on_crash    = 'restart'

# CashNetUSA configuration
extra=\"iface#{vlan0}=#{ip0}:255.255.255.0:#{gw0} iface4000=#{mgmt_ip_address}:255.255.254.0 fqdn=#{hostname.fqdn}\"

"
