#!/usr/bin/ruby 

module CNU::Enki

class Surealived

protected
def Surealived.select_check_interval(c)
  cluster_name = c.cluster_name
  case cluster_name
  when /smtp/ then
    5
  else
    1
  end
end

def Surealived.mkdir(file_name, dir_name)
  Dir.mkdir(dir_name) unless Kernel.test('d', dir_name)
  File.join(dir_name, file_name)
end

# make everything HTTP for now, but has ability to use different testers in the future
def Surealived.cluster_specific_info(cluster)
  # if cluster.name =~ /dns/
    # port = 53
    # tester_string = 'request="dns.example.com"'
  # else
    port = 80
    tester_string = 'url="/status"'
  # end
  {:port => port, :tester_string => tester_string, :timeout => 2, :retries2fail => 1, :retries2ok => 1}
end

def Surealived.write_llb_file(filename, datacenter, dcs)
  # select all clusters which have at least one server in each llb
  clusters = Cluster.all.select{|c| dcs.all?{|dc| c.nodes.any?{|n| n.is_server? and n.datacenter == dc}}}
  clusters = clusters.sort_by{|c| c.name}

  File.open( filename,'w') {|io|
    io.puts \
%Q(<!--
##################################################################
########       THIS FILE WAS AUTOMATICALLY GENERATED     #########
########   HAND MODIFCATIONS MAY BE LOST ON NEXT BOOT  ###########
# 
#{version_string()}
######## Surealived configuration for #{datacenter.name}
-->
<!-- <virtual name, addr, port, proto="tcp|udp|fwmark", sched, rt="dr|masq|tun", fwmark, pers></virtual> -->
<!-- <tester loopdelay, timeout, retries2ok, retries2fail, remove_on_fail="0|1", debugcomm="0|1",
    logmicro="0|1", proto, testport, ssl="On|Off"/> -->
<!-- <real name, addr, port, weight, uthresh, lthresh, testport, rt/> -->

<surealived>
)
    clusters.each {|c|
      if c.active?
        this_c = cluster_specific_info(c)
        io.puts  %Q(  <virtual name="#{c.name}" proto="fwmark" fwmark="#{c.fw_mark}" sched="wlc" rt="tun">
  <tester loopdelay="#{select_check_interval c}" timeout="#{this_c[:timeout]}" retries2fail="#{this_c[:retries2fail]}" retries2ok="#{this_c[:retries2ok]}"
    proto="http" testport="#{this_c[:port]}" #{this_c[:tester_string]} host="TEMP"/>
)
        nodes = c.cluster_nodes.select{|cn| cn.node.datacenter == datacenter}.sort_by{|cn| cn.node.hostname}
        nodes.each {|cn|
          io.puts \
          %Q(      <real name="#{cn.node.hostname}" addr="#{ip(cn.ip_address)}" port="#{this_c[:port]}" weight="100"/>) \
          if cn.node.is_server?
        }
        io.puts %Q(  </virtual>

)
      end
    }
  io.puts "</surealived>"
  }
end

public
  def Surealived.generate(filename, directory='')
    dc_llb_names = ['obr', 'nut']
    t = Time.now()

    dc_llbs = dc_llb_names.map{|name| Datacenter.find_by_name(name)}
    dc_llb_names.each{|dc_name|
      fn = mkdir(filename+'.'+dc_name+'.cfg', directory)
      write_llb_file(fn, Datacenter.find_by_name(dc_name), dc_llbs)
    }

    print_runtime(t, 'Surealived Config')
  end


end # class
end # module
