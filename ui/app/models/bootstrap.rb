class Bootstrap < ActiveRecord::Base
  named_scope :active, { :conditions => ["deleted is not true"] }
  named_scope :by_tag, lambda { |tag| { :conditions => ["uuid_tag = ? or service_tag =  ?", tag, tag] } }

  belongs_to :model, :foreign_key => 'model_id', :class_name => "CnuMachineModel"
  belongs_to :node 
  validates_presence_of :ip, :on => :update 

  def self.find_by_tag(tag)
      return nil if tag.nil?
      tag.strip!
      results = active.find(:all, :conditions => ["uuid_tag = ? or service_tag =  ?", tag, tag])
      return nil if results.empty?
      return results.first 
  end
  
  def self.find_by_any_tag(utag,stag)
      return nil if utag.nil? or stag.nil?
      r1 = active.by_tag(c(utag)).all
      r2 = active.by_tag(c(stag)).all
      results = [r1,r2].flatten
      return results
  end
  def self.create_from_post(p)
      found_model = CnuMachineModel.find_by_model_no(c(p["product_name"]))
      possible_node  = Node.find_by_serial_no(c(p["uuid_tag"]))
      possible_node_too  = Node.find_by_service_tag(c(p["service_tag"]))
      any_existing  = find_by_any_tag(p['uuid_tag'],p['service_tag'])
      rec = new()
      if any_existing.length > 0 then 
          rec = any_existing.first 
      end 
      ip_link = p['ip'] if p.has_key?('ip')
      rec.update_attributes({ :dmesg => p['dmesg'], 
          :dmidecode => p['dmidecode'],
          :proc_meminfo => p['proc_meminfo'],
          :proc_cpuinfo => p['proc_cpuinfo'],
          :uuid_tag => c(p['uuid_tag']),
          :service_tag => c(p['service_tag']),
          :product_name => c( p['product_name']),
          :ip => ip_link ,
#          :created_at => Date.today 
#          :updated_at => Date.today 
          :model => found_model ,
          :node => possible_node_too || possible_node ,
          :stage_one => false ,
          :stage_two => false
        })
      rec.process(false)
      rec
# Processing BootstrapsController#create (for 127.0.0.1 at 2009-11-07 16:55:44) [POST]
#  Session ID: 9795122727c62692f45dea992d7abc71
#  Parameters: {"proc_cpuinfo"=>"", "dmidecode"=>"dcode", "uuid_tag"=>"44454C4C-3300-1043-8035-B9C04F344431", "action"=>"create", "controller"=>"bootstraps", "proc_meminfo"=>"", "dmesg"=>"dmesg", "service_tag"=>"93C54D1", "product_name"=>"OptiPlex 745"}
  end
  def ready?(stage=nil)
    if stage.nil? then 
      stage_one? and stage_two?
    elsif stage == 1
      stage_one?
    elsif stage == 2
      stage_two?
    end
  end
  def process(saveme=true)
    parse_out_memory
    parse_out_nics
    attach_node
    attach_nics
    attach_node_data
    save! if saveme
  end 
  private
  def attach_node_data
     return if self.node.nil?
     return if self.model.nil? 
    self.node.model = self.model
    if self.node.serial_no.length < 1 then
        self.node.serial_no = self.uuid_tag
    end
    if self.node.service_tag.length < 1 then
        self.node.service_tag = self.service_tag
    end
    self.node.save
  end
  def attach_node 
      possible_node  = Node.find_by_serial_no(uuid_tag)
      possible_node_too  = Node.find_by_service_tag(service_tag)
      self.node_id = possible_node.id unless possible_node.nil?
      self.node_id = possible_node_too.id unless possible_node_too.nil?
  end
  def self.c(s)
    return '' if s.nil? 
    r = s.strip
    return r if r.length == 0 
    r.gsub!(/\s+/,' ')
    r
  end
  def parse_out_memory
     self.memory = proc_meminfo.split(/\s+/)[1]
  end
  def parse_out_nics
    require 'yaml'
    regex =  /: (eth\d+):.+link.ether (([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}) brd ([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$/
    lines = ip.grep(regex).map{|line| line =~ regex; [$2, $1]}
    self.nics = lines.to_yaml 
  end
  def  attach_nics
    return if node.nil?
    return unless node.nics.empty?  

    net_cards = YAML.load(self.nics)
    total = net_cards.length
    lan_cards = []
    san_cards = []
    lan_cards << net_cards.shift
    lan_cards << net_cards.shift

    san_cards << net_cards.pop
    san_cards << net_cards.pop
    lan_cards.concat(net_cards)

    lan_cards.compact.map do |nic|
        mac = nic.first
        port = nic.last 
        begin
        node.add_lan_nic(mac,port)
        rescue Object => e
        end
    end
    san_cards.compact.map do |nic|
        mac = nic.first
        port = nic.last 
        begin
        node.add_san_nic(mac,port)
        rescue Object => e
        end
    end
  end
end
