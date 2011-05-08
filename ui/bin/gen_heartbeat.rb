#!/usr/bin/ruby 

require 'network_nodes'

require 'cnu/enki/config_layout'

  include CNU::Enki::ConfigLayout

def find_services 
    svc = []
    Service.find_by_sql('select distinct ip_address, name from services order by ip_address').each { |s|
    svc << [s.ip_address, s.name]
  }
  svc
end 

def main
    svc = find_services 
    clusters = Cluster.find_all_active
    # puts svc.inspect 
    puts "Creating Heartbeat services #{svc.length} in #{clusters.length} clusters." if $VERBOSE
    begin
    ###
    fn = "ha.d/pacemaker_resources_cfg.xml" 
    # third parameter is nil so we get an execption if it is referenced
    write_pacemaker_resources(fn, clusters, nil, true)

    fn = 'ha.d/pacemaker_constraints_cfg.xml'
    write_constraints(fn, clusters)
    #
    rescue Object => e
      puts e.to_s
      puts FileUtils.pwd() 
    end
    
end
def timeout(a=nil)
  '15s'
end
def heartbeat_resource_group(c)
end
def heartbeat_port_forward_primitive(c, is_pacemaker=false)
  node_ip = ip(c.nodes.first.ip_address)
hb  = %Q(     <primitive id="ip_transfer_#{node_ip}" class="ocf" type="IPVS_port_forward" provider="cnu">
      <instance_attributes id="port_fwd_#{c.name}_ia">
        <attributes>
           <nvpair id="ip_#{node_ip}_fw" name="fwmark" value="#{c.fw_mark}"/>
           <nvpair id="ip_#{node_ip}_ip" name="ip" value="#{node_ip}"/>
        </attributes>
      </instance_attributes>
      <operations>
         <op id="portfwd_#{c.name}_op_start" name="start"   timeout="90s"/>
         <op id="portfwd_#{c.name}_op_stop" name="stop"    timeout="100s"/>
         <op id="portfwd_#{c.name}_op_monitor" name="monitor" timeout="30s" interval="137s"/>
      </operations> 
    </primitive>
)
pm = %Q(     <primitive id="ip_pf_#{node_ip}" class="ocf" type="IPVS_port_forward" provider="cnu">
       <meta_attributes id="ip_pf_#{node_ip}.meta"/>
      <instance_attributes id="port_fwd_#{c.name}_ia">
         <nvpair id="ip_#{node_ip}_fw" name="fwmark" value="#{c.fw_mark}"/>
         <nvpair id="ip_#{node_ip}_ip" name="ip" value="#{node_ip}"/>
      </instance_attributes>
      <operations>
         <op name="start" interval="0" id="portfwd_#{c.name}_op_start" timeout="90s"/>
         <op name="stop" interval="0" id="portfwd_#{c.name}_op_stop" timeout="100s"/>
         <op name="monitor" interval="137s" id="portfwd_#{c.name}_op_monitor" timeout="30s" />
      </operations> 
    </primitive>

)
  return pm if is_pacemaker
  return hb
end
def heartbeat_ldirectord_primitive(c, is_pacemaker=false)

configfile = %Q(                <nvpair id="ldirectord_#{c.name}_cf" name="configfile" value="/etc/cnu/configs/lvs/#{c.ldirectord_cfg_filename}"/>)
if is_pacemaker then
  meta = %Q(\n           <meta_attributes id="ldirectord_#{c.name}.meta" />)
  configpair = configfile
else
  meta = ''
  configpair =  %Q(               <attributes>
#{configfile}
              </attributes> 
)
end


shared = %Q(          <primitive id="ldirectord_#{c.name}" class="ocf" type="ldirectord" provider="heartbeat">#{meta}
            <instance_attributes id="ldirectord_#{c.name}_ia">
              #{configpair} 
            </instance_attributes>
            <operations>
               <op id="ldirectord_#{c.name}_op_start" name="start" timeout="90s"/>
               <op id="ldirectord_#{c.name}_op_stop" name="stop" timeout="100s"/>
               <op id="ldirectord_#{c.name}_op_monitor" name="monitor" timeout="30s" interval="113s"/>
            </operations> 
          </primitive>
)
  
hb = %Q(          <primitive id="ldirectord_#{c.name}" class="ocf" type="ldirectord" provider="heartbeat"> 
            <instance_attributes id="ldirectord_#{c.name}_ia">
              <attributes>
#{configfile} 
              </attributes>
            </instance_attributes>
            <operations>
               <op id="ldirectord_#{c.name}_op_start" name="start" timeout="90s"/>
               <op id="ldirectord_#{c.name}_op_stop" name="stop" timeout="100s"/>
               <op id="ldirectord_#{c.name}_op_monitor" name="monitor" timeout="30s" interval="113s"/>
            </operations> 
          </primitive>
)
pm = %Q(          <primitive id="ldirectord_#{c.name}" class="ocf" type="ldirectord" provider="heartbeat">#{meta}
            <instance_attributes id="ldirectord_#{c.name}_ia">
#{configfile}
            </instance_attributes>
            <operations>
               <op id="ldirectord_#{c.name}_op_start" name="start" timeout="90s" interval="0"/>
               <op id="ldirectord_#{c.name}_op_stop" name="stop" timeout="100s" interval="0"/>
               <op id="ldirectord_#{c.name}_op_monitor" name="monitor" timeout="29s" interval="113s"/>
            </operations> 
          </primitive>
)
  return pm if is_pacemaker
  return hb
end
def heartbeat_ha_ip_primitive(ip, is_pacemaker=false)
hb = %Q(          <primitive id="ip_#{ip}" class="ocf" type="IPaddr2" provider="heartbeat"> 
           <instance_attributes id="ip_#{ip}_ia">
             <attributes>
              <nvpair id="ip_#{ip}_ip" name="ip" value="#{ip}"/>
              <nvpair id="ip_#{ip}_nm" name="cidr_netmask" value="32"/>
              </attributes>
            </instance_attributes>
            <operations>
               <op id="ip_#{ip}_op_start" name="start"   timeout="90s"/>
               <op id="ip_#{ip}_op_stop" name="stop"    timeout="100s"/>
               <op id="ip_#{ip}_op_monitor" name="monitor" timeout="30s" interval="149s"/>
            </operations> 
          </primitive>)
pm = %Q(          <primitive id="ip_#{ip}" class="ocf" type="IPaddr2" provider="heartbeat"> 
        
           <meta_attributes id="ip_#{ip}.meta" />
           <instance_attributes id="ip_#{ip}_ia">
              <nvpair id="ip_#{ip}_ip" name="ip" value="#{ip}"/>
              <nvpair id="ip_#{ip}_nm" name="cidr_netmask" value="32"/>
            </instance_attributes>
            <operations>
               <op id="ip_#{ip}_op_start" name="start" interval="0" timeout="90s"/>
               <op id="ip_#{ip}_op_stop" name="stop" interval="0" timeout="100s"/>
               <op id="ip_#{ip}_op_monitor" name="monitor" timeout="30s" interval="149s"/>
            </operations> 
          </primitive>)
  return pm if is_pacemaker
  return hb
end

def write_pacemaker_resources(fn, clusters,loadbalancer_cnt,is_pacemaker=true) 
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') do |io|
      io.puts "<!--
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
# -->
<resources>"
     cnt = 0
     clusters.each { |c| 
        next unless c.active? 
        print "#{c.fw_mark} " if $VERBOSE
        io.puts %Q(     <group id="#{c.name}_group" description="#{c.fw_mark}:#{c.name} - #{c.title}" >)
        if is_pacemaker then
          io.puts %Q(     <meta_attributes id="#{c.name}_group.meta" />) 
        end
        if c.load_balanced? then
          io.puts heartbeat_ldirectord_primitive(c, is_pacemaker)
        else
          io.puts heartbeat_port_forward_primitive(c, is_pacemaker) 
        end
        c.ha_ip_address.each{|ip|
          io.puts heartbeat_ha_ip_primitive(ip,is_pacemaker)
        }
        io.puts "     </group>"
        cnt = cnt + 1
    }
#############################################################################################33
#
#   Timeouts must be at least 20 seconds because the PDUs are slow, 
#   It is set to 30 to handle network issues
#   Check interval is every 5 minutes.
#
#############################################################################################33
    if is_pacemaker then
    io.puts %Q(<!-- stonith configuration -->
     <clone id="stonith-apc-set">
        <meta_attributes id="stonith_ia">
           <nvpair id="stonith_nv1" name="clone-node-max" value="1"/>
        </meta_attributes>
        <primitive id="stonith-apc" class="stonith" type="external/cnu_apcsnmp_stonith">
          <meta_attributes id="stonith-apc.meta" />
          <operations>
              <op id="stonith_op_start"   name="start" timeout="30s" interval="0" requires="nothing" on-fail="restart"/>
              <op id="stonith_op_monitor" name="monitor" timeout="30s" interval="300s" requires="nothing" on-fail="restart"/>
          </operations>
        </primitive>
     </clone>)
    else
    io.puts %Q(<!-- stonith configuration -->
          <clone id="stonith-apc-set">
            <instance_attributes id="stonith_ia">
              <attributes>
                <nvpair id="stonith_nv1" name="clone_max" value="#{loadbalancer_cnt}"/>
                <nvpair id="stonith_nv2" name="clone_node_max" value="1"/>
              </attributes>
            </instance_attributes>
            <primitive id="stonith-apc" class="stonith" type="external/cnu_apcsnmp_stonith">
            <operations>
              <op id="stonith_op_start"   name="start" timeout="30s" prereq="nothing" on_fail="restart"/>
              <op id="stonith_op_monitor" name="monitor" timeout="30s" interval="300s" prereq="nothing" on_fail="restart"/>
            </operations>
            </primitive>
          </clone>)
    end
#############################################################################################33

    io.puts "</resources>"
  end
end
def write_heartbeat_resources(fn, clusters,loadbalancer_cnt) 
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') do |io|
      io.puts "<!--
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
# -->
<resources>"
     cnt = 0
     clusters.each { |c| 
        next unless c.active? 
        print "#{c.fw_mark} " if $VERBOSE
        io.puts %Q(     <group id="#{c.name}_group" description="#{c.fw_mark}:#{c.name} - #{c.title}" >)
        if c.load_balanced? then
          io.puts heartbeat_ldirectord_primitive(c) 
        else
          io.puts heartbeat_port_forward_primitive(c) 
        end
        c.ha_ip_address.each{|ip|
          io.puts heartbeat_ha_ip_primitive(ip)
        }
        io.puts "     </group>"
        cnt = cnt + 1
    }
#############################################################################################33
#
#   Timeouts must be at least 20 seconds because the PDUs are slow, 
#   It is set to 30 to handle network issues
#   Check interval is every 5 minutes.
#
#############################################################################################33
    io.puts %Q(<!-- stonith configuration -->
          <clone id="stonith-apc-set">
            <instance_attributes id="stonith_ia">
              <attributes>
                <nvpair id="stonith_nv1" name="clone_max" value="#{loadbalancer_cnt}"/>
                <nvpair id="stonith_nv2" name="clone_node_max" value="1"/>
              </attributes>
            </instance_attributes>
            <primitive id="stonith-apc" class="stonith" type="external/cnu_apcsnmp_stonith">
            <operations>
              <op id="stonith_op_start"   name="start" timeout="30s" prereq="nothing" on_fail="restart"/>
              <op id="stonith_op_monitor" name="monitor" timeout="30s" interval="300s" prereq="nothing" on_fail="restart"/>
            </operations>
            </primitive>
          </clone>)
#############################################################################################33
    io.puts "</resources>"
  end
end



# file works wiht pacemaker and heartbeat both

def write_constraints(fn, clusters)
  puts "Write out file: #{fn}" if $VERBOSE
  File.open( fn,'w') do |io|
      io.puts "<!--
##################################################################
########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
#{version_string()}
# -->
<constraints>"
  cnt = 0 
  clusters.each {|c| 
     id = "rscloc_#{c.name}_group"
      io.puts %Q(     <rsc_location id="#{id}" rsc="#{c.name}_group">
       <rule id="#{id}_r1" score="-INFINITY">
         <expression attribute="CNU_COLO" operation="ne" value="ACTIVE" id="#{id}_e1" />
       </rule>
       <rule id="#{id}_r2" score="1000">
         <expression attribute="CNU_COLO" operation="eq" value="ACTIVE" id="#{id}_e2" />
       </rule>
     </rsc_location>)
    cnt = cnt + 1
  }
    io.puts "</constraints>"
  end 
end

main()


__END__

Monitoroutput:
Resource Group: uuportal_group
    ldirectord_uuportal (ocf::heartbeat:ldirectord):    Started load2.dc1.example.com
    ip_uuportal_10.10.10.101    (ocf::heartbeat:IPaddr2):       Started load2.dc1.example.com


CONSTRAINTS:
<!--
##################################################################
#########       THIS FILE WAS AUTOMATICLY GENERATED     ###########
#########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
#########  generated on Sep 25, 2008 15:23:21 by gen_heartbeat.rb 
## -->
<!-- only run in dc1 -->
<constraints>

  <rsc_location id="rscloc_01" rsc="uuportal_group">
      <rule score="-INFINITY" >
    <expression attribute="CNU_COLO" operation="ne" value="ACTIVE" />
               </rule>
                    <rule score="1000" >
                          <expression attribute="CNU_COLO" operation="eq"
                          value="ACTIVE"  />
                              </rule>
                                </rsc_location>

   <!--  <rsc_order id="uuportal_group_order"
           from="ldirectord_uuportal" action="start"
         type="before" to="ip_uuportal_10.10.10.101"
                    symmetrical="true"/> -->

</constraints>
Resources:
<!-- ########  generated on Sep 25, 2008 15:23:21 by gen_heartbeat.rb # -->
<resources>

        <group id="uuportal_group">

          <primitive id="ldirectord_uuportal" class="ocf" type="ldirectord" provider="heartbeat"> 
            <instance_attributes>
              <attributes>
                <nvpair name="configfile" value="/etc/cnu/configs/lvs/ldirectord_uuportal.cfg"/>
              </attributes>
            </instance_attributes>
          </primitive>
        
          <primitive id="ip_uuportal_10.10.10.101" class="ocf" type="IPaddr2" provider="heartbeat"> 
            <instance_attributes>
              <attributes>
                 <nvpair name="ip" value="10.10.10.101"/>
                 <nvpair name="cidr_netmask" value="32"/>
              </attributes>
            </instance_attributes>
          </primitive>
        
        </group>

</resources>
(09:01:13 AM) Michael Vallaly: so the only two caveats.. are ldirectord entries should always come before the IPs

#            <nvpair name="iflabel" value="#{name}"/>
#            <nvpair name="cidr_netmask" value="24"/>
#            <nvpair name="lvs_support" value="true"/>
#            <nvpair name="local_stop_script" value="true"/>
#            <nvpair name="local_start_script" value="true"/>
#            <nvpair name="local_stop_script" value="true"/>

<primitive id="ip_1" class="ocf" type="IPaddr2" provider="heartbeat"  > 
  <instance_attributes>
    <attributes>
      <nvpair name="ip" value="10.10.10.1"/>
      <nvpair name="cidr_netmask" value="24"/>
      <nvpair name="iflabel" value="servicename"/>
      <nvpair name="lvs_support" value="true"/>
      <nvpair name="local_stop_script" value="true"/>
      <nvpair name="local_start_script" value="true"/>
      <nvpair name="local_stop_script" value="true"/>
    </attributes>
  </instance_attributes>
</primitive>

<!-- only run in dc1 -->
<constraints>
<rsc_location id="main_colo_location" >
  <rule score="-INFINITY" boolean_op="and" id="rule_to_always_use_dc1">
    <expression attribute="#uname" operation="ne" value="load1.dc1.example.com" id="expr:h1">
    <expression attribute="#uname" operation="ne" value="load2.dc1.example.com" id="expr:h2">
</rule>
</rsc_location>
</constraints>
