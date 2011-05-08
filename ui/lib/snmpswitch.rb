
## Usage
##  require 'snmpswitch'
##  auth = {:user => "youruser", :auth_proto => "MD5", :auth_pass => "authpass", :sec_level => "authPriv", :priv_proto => "DES", :priv_pass => "privpass", :hostname => "switchhostorip"}
##  snmp = CSNMP.new(auth)
##  hp = HPSwitch.new(snmp)
##  hp.port("A1")             # returns the interface number for supplied port name
##  hp.port_by_id(1)          # returns port name for supplied interface number
##  hp.interfaces             # returns array of interface ids and names [["1", "A1"], ["2", "A2"]]
##  hp.vlan("OLDBOOTSTRAP")   # returns vlan id for supplied name
##  hp.vlan_by_id(1)          # returns vlan name for supplied id
##  hp.vlans                  # returns array of vlan IDs and names [["1", "SOMEVLAN"], ["2", "OTHERVLAN"]]
##
##  hp.port_is_untagged?(1)   # returns tagged vlan or nil
##
##  hp.vlan_info(1)           # returns array of port statuses for supplied vlan id [["A1", "TAGGED"], ["A2", "UNTAGGED"]]
##  hp.port_info(1)           # returns array of vlan statuses for supplied port id [["1", "SOMEVLANNAME", "NO"], ["2", "OTHERVLAN", "TAGGED"]]
##
##  hp.clear(vlan_id, port_id)  # clears vlan status on port aka "NO"
##  hp.tag(vlan_id, port_id)    # tags the vlan on supplied port
##  hp.untag(vlan_id, port_id)  # untags the vlan on supplied port
##  hp.forbid(vlan_id, port_id) # forbids the vlan on supplied port
##
##  hp.save                   # saves all vlan changes to the switch via snmp
##  hp.refresh                # discards all changes and reads fresh data from switch

## Test switch: auth = {:user => "testuser", :auth_proto => "MD5", :auth_pass => "authpass", :sec_level => "authPriv", :priv_proto => "DES", :priv_pass => "authpass", :hostname => "192.0.2.4"}

DEBUG = false
VERBOSE = false


class CSNMP

  def initialize(auth_options)
    @auth = auth_options
  end

  private

  def snmp_options
   a = @auth
   "-v 3 -u #{a[:user]} -a #{a[:auth_proto]} -A #{a[:auth_pass]} -l #{a[:sec_level]} -x #{a[:priv_proto]} -X #{a[:priv_pass]}"
  end

  def hostname
    @auth[:hostname]    
  end

  def execute(cmd)
    puts cmd if DEBUG
    rc = %x{#{cmd}}
    puts rc.inspect if DEBUG
    rc
  end

  public

  def snmpset(oid, hex)
    execute("snmpset #{snmp_options} #{hostname} #{oid} x '#{hex}'")
  end

  def snmpwalk(oid)
    execute("snmpwalk #{snmp_options} -OQ #{hostname} #{oid}")
  end
end

class HPSwitch

  attr_accessor :interfaces, :vlans

  @@oid_tagged    = '.1.3.6.1.2.1.17.7.1.4.3.1.2'
  @@oid_untagged  = '.1.3.6.1.2.1.17.7.1.4.3.1.4'
  @@oid_forbidden = '.1.3.6.1.2.1.17.7.1.4.3.1.3'
  @@oid_interfaces= '1.3.6.1.2.1.31.1.1.1.1'
  @@oid_vlans     = '1.3.6.1.2.1.17.7.1.4.3.1.1'

  @snmp_inst = nil
  @tagged_bitmap = nil
  @untagged_bitmap = nil
  @forbidden_bitmap = nil

  @ports_touched = nil

  @save_step1 = nil
  @save_step2 = nil

  def save
    puts "SETTING" if VERBOSE
    @save_step2.each do |vlan, v|
      # SET UNTAGGED TO 0
      puts "CLEARING UNGTAGGED FOR MODIFIED PORTS, VLAN: #{vlan}" if VERBOSE
      @snmp_inst.snmpset("#{@@oid_untagged}.#{vlan}", bitmap_to_hex(touched_ports_clear_untag(vlan)))    
    end
    @save_step2.each do |vlan, v|
      # SET FORBID TO 0
      puts "CLEARING FORBID, VLAN: #{vlan}" if VERBOSE
      @snmp_inst.snmpset("#{@@oid_forbidden}.#{vlan}", bitmap_to_hex(blank_bitmap()))
    end
    @save_step2.each do |vlan, v|
      # SET TAGGED (ENABLED ONLY)
       puts "SET TAGGED (ENABLED ONLY), VLAN: #{vlan}" if VERBOSE
      @snmp_inst.snmpset("#{@@oid_tagged}.#{vlan}", bitmap_to_hex(tagged_enabled(vlan)))
    end
    @save_step2.each do |vlan, v|
      # SET FULL TAGGED
      puts "SET FULL TAGGED, VLAN: #{vlan}" if VERBOSE
      @snmp_inst.snmpset("#{@@oid_tagged}.#{vlan}", bitmap_to_hex(v[:tagged]))
    end
    @save_step2.each do |vlan, v|
      # SET FULL UNTAGGED
      puts "SET FULL UNTAGGED, VLAN: #{vlan}" if VERBOSE
      @snmp_inst.snmpset("#{@@oid_untagged}.#{vlan}", bitmap_to_hex(v[:untagged]))
    end
    @save_step2.each do |vlan, v|
      # SET FULL FORBID
      puts "SET FORBID, VLAN: #{vlan}" if VERBOSE
      @snmp_inst.snmpset("#{@@oid_forbidden}.#{vlan}", bitmap_to_hex(v[:forbidden]))

      ##@snmp_inst.snmpset("#{@@oid_tagged}.#{vlan}", bitmap_to_hex(v[:tagged]))
    end
    refresh()
  end

  def initialize(auth_options = {})
    @snmp_inst = CSNMP.new(auth_options)
    refresh()
  end

  def refresh
    @interfaces = get_interfaces()
    @vlans = get_vlans()
    @tagged_bitmap = get_tagged()
    @untagged_bitmap = get_untagged()
    @forbidden_bitmap = get_forbidden()
    @ports_touched = []
    @save_step1 = {}
    @save_step2 = {}
  end

  def p_current(vlan_id)
    vlan_id = vlan_id.to_s
    return nil unless @save_step2.has_key?(vlan_id)
    t = @save_step2[vlan_id][:tagged]
    u = @save_step2[vlan_id][:untagged]
    f = @save_step2[vlan_id][:forbidden]

    @interfaces.each do |i|
      puts "Interface #{i[1]} is TAGGED" if t[i[0].to_i-1,1] == "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] != "1"
      puts "Interface #{i[1]} is UNTAGGED" if t[i[0].to_i-1,1] == "1" and u[i[0].to_i-1,1] == "1" and f[i[0].to_i-1,1] != "1"
      puts "Interface #{i[1]} is FORBIDDEN" if t[i[0].to_i-1,1] != "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] == "1"
    end
  end

  def p_orig(vlan_id)
    t = @tagged_bitmap.assoc(vlan_id.to_s)[1]
    u = @untagged_bitmap.assoc(vlan_id.to_s)[1]
    f = @forbidden_bitmap.assoc(vlan_id.to_s)[1]

    if DEBUG and VERBOSE
      puts "tagged bitmap"
      pp t
      puts "untagged bitmap"
      pp u
      puts "forbidden bitmap"
      pp f
    end
    
    @interfaces.each do |i|
      puts "Interface #{i[1]} is TAGGED" if t[i[0].to_i-1,1] == "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] != "1"
      puts "Interface #{i[1]} is UNTAGGED" if t[i[0].to_i-1,1] == "1" and u[i[0].to_i-1,1] == "1" and f[i[0].to_i-1,1] != "1"
      puts "Interface #{i[1]} is FORBIDDEN" if t[i[0].to_i-1,1] != "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] == "1"
    end
  end

  def port_info(port_id)
    @vlans.map { |v|
      status = [@forbidden_bitmap.assoc(v[0])[1][port_id-1,1],
                @tagged_bitmap.assoc(v[0])[1][port_id-1,1],
                @untagged_bitmap.assoc(v[0])[1][port_id-1,1]].to_s
      status_text = case status
        when "000"
          "NO"
        when "100"
          "FORBIDDEN"
        when "010"
          "TAGGED"
        when "011"
          "UNTAGGED"
        else
          "WTF ERROR"
      end
      
      [v[0], v[1], status_text]
    }
  end

  def port_is_untagged?(port_id)
    tmp = port_info(port_id)
    tmp.each { |v|
      return v if v[2] == "UNTAGGED"
    }
    nil
  end

  def vlan_info(vlan_id)
    t = @tagged_bitmap.assoc(vlan_id.to_s)[1]
    u = @untagged_bitmap.assoc(vlan_id.to_s)[1]
    f = @forbidden_bitmap.assoc(vlan_id.to_s)[1]

    @interfaces.map { |i|
      status = "WTF DUDE"
      status = "TAGGED" if t[i[0].to_i-1,1] == "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] != "1"
      status = "UNTAGGED" if t[i[0].to_i-1,1] == "1" and u[i[0].to_i-1,1] == "1" and f[i[0].to_i-1,1] != "1"
      status = "FORBIDDEN" if t[i[0].to_i-1,1] != "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] == "1"
      status = "NO" if t[i[0].to_i-1,1] != "1" and u[i[0].to_i-1,1] != "1" and f[i[0].to_i-1,1] != "1"
      ["#{i[1]}", status]
    }
  end

  def can_clear?(vlan_id, interface)
    !port_info(interface).select{|i| i[2] == "TAGGED" or i[2] == "UNTAGGED"}.select{|i| i[0].to_i != vlan_id}.empty?
  end

  def clear(vlan_id, interface)
    return nil unless can_clear?(vlan_id, interface)

    unless @save_step2.has_key?(vlan_id)
      @save_step2[vlan_id] = {:tagged => @tagged_bitmap.assoc(vlan_id.to_s)[1].clone, :untagged => @untagged_bitmap.assoc(vlan_id.to_s)[1].clone, :forbidden => @forbidden_bitmap.assoc(vlan_id.to_s)[1].clone}
    end

    @ports_touched << [vlan_id, interface]

    @save_step2[vlan_id][:tagged][interface - 1] = "0"
    @save_step2[vlan_id][:untagged][interface - 1] = "0"
    @save_step2[vlan_id][:forbidden][interface - 1] = "0"
  end

  def tag(vlan_id, interface)
    unless @save_step2.has_key?(vlan_id)
      @save_step2[vlan_id] = {:tagged => @tagged_bitmap.assoc(vlan_id.to_s)[1].clone, :untagged => @untagged_bitmap.assoc(vlan_id.to_s)[1].clone, :forbidden => @forbidden_bitmap.assoc(vlan_id.to_s)[1].clone}
    end

    @ports_touched << [vlan_id, interface]

    @save_step2[vlan_id][:tagged][interface - 1] = "1"
    @save_step2[vlan_id][:untagged][interface - 1] = "0"
    @save_step2[vlan_id][:forbidden][interface - 1] = "0"
  end

  def untag(vlan_id, interface)
    unless @save_step2.has_key?(vlan_id)
      @save_step2[vlan_id] = {:tagged => @tagged_bitmap.assoc(vlan_id.to_s)[1].clone, :untagged => @untagged_bitmap.assoc(vlan_id.to_s)[1].clone, :forbidden => @forbidden_bitmap.assoc(vlan_id.to_s)[1].clone}
    end

    @ports_touched << [vlan_id, interface]

    ## ONLY ONE VLAN CAN BE UNTAGGED PER PORT
    untagged = port_is_untagged?(interface)
    unless untagged.nil?
      forbid(untagged[0].to_i, interface)
    end

    @save_step2[vlan_id][:tagged][interface - 1] = "1"
    @save_step2[vlan_id][:untagged][interface - 1] = "1"
    @save_step2[vlan_id][:forbidden][interface - 1] = "0"
  end

  def can_forbid?(vlan_id, interface)
    !port_info(interface).select{|i| i[2] == "TAGGED" or i[2] == "UNTAGGED"}.select{|i| i[0].to_i != vlan_id}.empty?
  end

  def forbid(vlan_id, interface)
    return nil unless can_forbid?(vlan_id, interface)

    unless @save_step2.has_key?(vlan_id)
      @save_step2[vlan_id] = {:tagged => @tagged_bitmap.assoc(vlan_id.to_s)[1].clone, :untagged => @untagged_bitmap.assoc(vlan_id.to_s)[1].clone, :forbidden => @forbidden_bitmap.assoc(vlan_id.to_s)[1].clone}
    end

    @ports_touched << [vlan_id, interface]

    @save_step2[vlan_id][:tagged][interface - 1] = "0"
    @save_step2[vlan_id][:untagged][interface - 1] = "0"
    @save_step2[vlan_id][:forbidden][interface - 1] = "1"
  end

  def port(port_name)
    @interfaces.rassoc(port_name)[0].to_i 
  end

  def port_by_id(id)
    @interfaces.assoc(id.to_s)[1]
  end

  def vlan(vlan_name)
    @vlans.rassoc(vlan_name)[0].to_i
  end

  def vlan_by_id(id)
    @vlans.assoc(id.to_s)[1]
  end

  def to_html

    ports = self.interfaces.map{|i| "<th>#{i[1]}</th>"}.join("\n")
    vlans = self.vlans.map{|v| ["<tr>", "<td>#{v[1]}</td>", self.vlan_info(v[0].to_i).map{|i| "<td class='#{i[1]}'>#{i[1][0,1]}</td>"}.join("\n"), "</tr>"]}.join("\n")

    "<html><body> <style>
        table { font-size: 11px; }
        .NO { background-color: #bbf;}
        .TAGGED { background-color: #bfb;}
        .UNTAGGED { background-color: #fda;}
        .FORBIDDEN { background-color: #fbb;}
      </style>
      <table>
      <tr>
        <th>VLAN</th>
        #{ports}
      </tr>
      #{vlans}
      </table></body></html>"
  end

  private

  def bitmap_to_hex(vlan_bitmap)
    #mp = "%0*s"%[104, vlan_bitmap.to_i(base=2).to_s(base=16)]
    #mp.gsub(" ", "0").upcase.gsub(/(..)/, '\1 ').rstrip
    vlan_bitmap.scan(/[01]{4}/).map{|i|
     i.to_i(2).to_s(16)
      }.join
  end

  def hex_to_bitmap(hex_string)
    grr = { "0" => "0000", "1" => "0001", "2" => "0010", "3" => "0011", "4" => "0100", "5" => "0101", "6" => "0110", "7" => "0111", "8" => "1000", "9" => "1001", "A" => "1010", "B" => "1011", "C" => "1100", "D" => "1101", "E" => "1110", "F" => "1111" }

    tmp = []
    hex_string.each_char{|c| tmp << grr[c] }
    tmp.to_s
  end

  def blank_bitmap
    "0"*@untagged_bitmap[0][1].length
  end
public
  def touched_ports_clear_untag(vlan_id)
    old = @untagged_bitmap.assoc(vlan_id.to_s)[1].clone
    new = old.clone
    touched = @ports_touched#.map{|p| p[1]-1}
    for i in touched
      if i[0] = vlan_id
        new[i[1] - 1] = "0"
      end
    end
    new
  end
private
  def tagged_enabled(vlan_id)
    old = @tagged_bitmap.assoc(vlan_id.to_s)[1].clone

    if @save_step2.has_key?(vlan_id)
      new = @save_step2[vlan_id][:tagged]
      i = @untagged_bitmap[0][1].length
      return "%0*b"%[i,(old.to_i(2) | new.to_i(2))]
    end

    old
  end

  def bitmap_to_port(vlan_bitmap)
    @interfaces.map { |i|
      [i[1], vlan_bitmap[1][i[0].to_i - 1,1].to_i == 1? true : false] if i[0].to_i <= 409
    }.compact
  end

  def get_interfaces
    @snmp_inst.snmpwalk(@@oid_interfaces).split("\n").map { |s|
      tmp = s.split(" = ")
      tmp[0].sub!("IF-MIB::ifName.", "")
      tmp if tmp[0].to_i <= 409
    }.compact
  end

  def get_vlans
    @snmp_inst.snmpwalk(@@oid_vlans).split("\n").map { |s|
      tmp = s.split(" = ")
      tmp[0].sub!("SNMPv2-SMI::mib-2.17.7.1.4.3.1.1.", "")
      tmp[1].gsub!("\"", "")
      tmp
    }
  end

  def get_untagged
    @snmp_inst.snmpwalk(@@oid_untagged).split(" \"\n").map { |s| 
      tmp = s.split(" = ")
      tmp[0].sub!("SNMPv2-SMI::mib-2.17.7.1.4.3.1.4.", "")
      tmp[1].sub!("\"", "")
      tmp[1].gsub!("\n", "")
      #tmp[1] = tmp[1].gsub(" ", "").to_i(base=16).to_s(base=2)
      tmp[1] = hex_to_bitmap(tmp[1].gsub(" ", ""))
      tmp       
    }
  end

  def get_tagged
    @snmp_inst.snmpwalk(@@oid_tagged).split(" \"\n").map { |s|     
      tmp = s.split(" = ")
      tmp[0].sub!("SNMPv2-SMI::mib-2.17.7.1.4.3.1.2.", "")
      tmp[1].sub!("\"", "")
      tmp[1].gsub!("\n", "")
      #tmp[1] = tmp[1].gsub(" ", "").to_i(base=16).to_s(base=2)
      tmp[1] = hex_to_bitmap(tmp[1].gsub(" ", ""))
      tmp       
    }
  end

  def get_forbidden
    @snmp_inst.snmpwalk(@@oid_forbidden).split(" \"\n").map { |s|     
      tmp = s.split(" = ");
      tmp[0].sub!("SNMPv2-SMI::mib-2.17.7.1.4.3.1.3.", "");
      tmp[1].sub!("\"", "");
      tmp[1].gsub!("\n", "");
      #tmp[1] = tmp[1].gsub(" ", "").to_i(base=16).to_s(base=2)
      tmp[1] = hex_to_bitmap(tmp[1].gsub(" ", ""))
      tmp       
    }
  end


end
