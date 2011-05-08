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

def plug_network(host, switch, port)
  puts host.to_label
  puts switch.to_label
  puts port
  begin
    nsp = NetworkSwitchPort.plug(switch, host,  port)
    unless nsp.save then
      puts "ERROR: Switch port could not be saved"
    end
  rescue Exception => e
    puts "Exception!"
  end
end

def plug_scs(host, scs, port)
  begin
    sc_plug = SerialConsole.plug_node_into_scs(host, scs, port.to_i)
    unless sc_plug and sc_plug.save then
      puts "ERROR: SerialConsole could not be saved"
    end
  rescue Exception => e
    puts "Exception!"
  end
end

def plug_pdu(host, pdu, port)
  nsp = host.plug_into(pdu, port)
  unless nsp and nsp.save then
    puts "ERROR: PDU could not be saved!"
  end
end


def run(file)
  File.open(file, "r") do |io|
    while (line = io.gets)
      
      data = line.split(",")
      node = data[0].split(".")
      n = Node.find_by_name(node[0], node[1])
      unless n.nil?
        if data[1] =~ /.*lan.*/
          plug_network(n, Node.find_by_name("hpswi001", "nut"), data[3].upcase.chomp)
        end
        if data[1] =~ /.*san.*/
          plug_network(n, Node.find_by_name("hpswi002", "nut"), data[3].upcase.chomp)
        end
        if data[1] == "serial"
          scs_parts = data[2].split(".")
          s = Node.find_by_name(scs_parts[0], scs_parts[1])
          unless s.nil?
            plug_scs(n, s, data[3].to_i)
          end
        end
      end
    end
  end
end

if ARGV.count == 1
  puts "RUNNING!"
  run ARGV[0]
end

__END__
