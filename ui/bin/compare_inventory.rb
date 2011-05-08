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

require 'pp'
require 'csv'

import_file = nil

if ARGV.member?("-F")
  import_file = ARGV[ARGV.index("-F") + 1]
else
  puts "Requires input file. Use -F FILENAME"
  exit
end

reader = CSV.open(import_file, "r")
header = reader.shift

fixit = false
datacenter = "obr"
cur_host = Node.new

if ARGV.member?("-fixit")
  fixit = true
  puts "Making changes to CFG DB"
end

reader.each do |row|

  next if row[0].nil? or row[0].length == 0

  if cur_host.nil? or "#{row[0]}.obr" != cur_host.fn_prefix
    cur_host = Node.find_by_name(row[0], datacenter)
  end

  next if cur_host.nil?

  if !row[3].nil? and row[3].length > 0

    case row[1]
      when "serial"
        if cur_host.serial_consoles.empty?
          puts "NOTICE [SERIAL][#{cur_host.fn_prefix}]: CFG has no record of #{cur_host.fn_prefix} plugged into #{row[3]} port #{row[4]}"
          if fixit and not row[4].nil?
            begin
              scs = Node.find_by_name(row[3], datacenter)
              SerialConsole.plug_node_into_serial_console(cur_host, scs, row[4])
            rescue Exception => e
              puts "ERROR [SERIAL][#{cur_host.fn_prefix}]: Couldnt plug serial console. #{e.to_s}"
            end
          else
              puts "ERROR [SERIAL][#{cur_host.fn_prefix}]: port number blank for #{row[1]}" if
row[4].nil?
          end
        else
          if cur_host.serial_consoles.first.scs.hostname != row[3]
            puts "WARNING [SERIAL][#{cur_host.fn_prefix}]: Plug mismatch. CFG: #{cur_host.serial_consoles.first.scs.hostname} port #{cur_host.serial_consoles.first.port}  INV: #{row[3]} port #{row[4]}"
          end
        end
  
        when "power"
        if cur_host.pdus.empty?
          puts "NOTICE [PDU][#{cur_host.fn_prefix}]: CFG has no record of #{cur_host.fn_prefix} plugged into #{row[3]} port #{row[4]}"
          if fixit and not row[4].nil?
            begin
              pdu = Node.find_by_name(row[3], datacenter)
              nsp = cur_host.plug_into(pdu, row[4])
              unless nsp and nsp.save then
                puts "ERROR [PDU][#{cur_host.fn_prefix}]: couldnt plug pdu. #{nsp.errors.full_messages}"
              end
            rescue Exception => e
              puts "ERROR [PDU][#{cur_host.fn_prefix}]: Error plugging PDU: #{e.to_s}"
            end
          else
              puts "ERROR [PDU][#{cur_host.fn_prefix}]: port number blank for #{row[1]}" if row[4].nil?
          end
        else
          pdus = cur_host.pdus.map { |p| p.pdu.hostname }
          unless pdus.include?(row[3])
            puts "WARNING [PDU][#{cur_host.fn_prefix}]: PDU Plug mismatch. CFG: #{pdus.join(", ")} INV: #{row[3]} port #{row[4]}"
          end
        end
      when "lan", "san"
        if row[8]
          if cur_host.network_switch_ports.empty?
            puts "NOTICE [NETWORK][#{cur_host.fn_prefix}]: CFG has no record of #{cur_host.fn_prefix} plugged into #{row[1]} switch port #{row[8]}"
            if fixit and not row[8].nil?
              begin
                sw = nil
                sw = Node.find_by_name("hpswi001", datacenter) if row[1] == "lan"
                sw = Node.find_by_name("hpswi002", datacenter) if row[1] == "san"
                nsp = NetworkSwitchPort.plug(sw, cur_host, row[8])
                unless nsp.save
                  puts "ERROR [NETWORK][#{cur_host.fn_prefix}]: couldnt plug switch: #{nsp.errors.full_messages}"
                end
              rescue Exception => e
                puts "ERROR [NETWORK][#{cur_host.fn_prefix}]: couldnt plug switch port: #{e.to_s}"
              end
            else
              puts "ERROR [NETWORK][#{cur_host.fn_prefix}]: port number blank for #{row[1]}" if row[8].nil?
            end
          else
            ports = cur_host.network_switch_ports.map { |p| p.port }
            unless ports.include?(row[8])
              puts "WARNING [NETWORK][#{cur_host.fn_prefix}]: Network Switch Port mismatch. CFG: #{ports.join(", ")} INV: #{row[8]}"
            end
          end
        end
      else
        puts "ERROR: #{row[0]}.#{datacenter} Unknown inventory plug type '#{row[1]}'"
    end

  end

end
