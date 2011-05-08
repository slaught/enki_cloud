class Rampart < ActiveRecord::Base
  belongs_to :node
  belongs_to :public_ip_address, :foreign_key => 'public_ip_address_id', :class_name => 'IpAddress'
  belongs_to :locale_ip_address, :foreign_key => 'locale_ip_address_id', :class_name => 'IpAddress'
  has_many :rampart_services
  validates_presence_of :node_id
  validate :has_ip_if_checked
  validates_inclusion_of :public_ip_address_id, :in => [nil], :unless => :has_public_ip?,
    :message => "exists but 'has public ip' is not checked"
  validates_inclusion_of :locale_ip_address_id, :in => [nil], :unless => :has_service_ip?,
    :message => "exists but 'has service ip' is not checked"
  validates_inclusion_of :has_public_ip, :in => [true, false]
  validates_inclusion_of :has_service_ip, :in => [true, false]
  before_validation :clear_empty_attrs
  after_update :destroy_changed_ips
  after_destroy :destroy_unused_ips
  has_paper_trail

private
  def self.public_network
    Network.all.detect{|n| n.description =~ /Ram(parts)*\s+Public$/i}
  end  
  def self.locale_network
    Network.all.detect{|n| n.description =~ /Ram(parts)*\s+Locale$/i}
  end
  def has_ip_if_checked
    if has_public_ip? and (public_ip_address_id.nil? and public_ip_address.nil?)
      errors.add(:public_ip_address, "can't be blank if 'has public ip' is checked")
    end
    if has_service_ip? and (locale_ip_address_id.nil? and locale_ip_address.nil?)
      errors.add(:locale_ip_address, "can't be blank if 'has service ip' is checked")
    end
  end
  def has_public_ip?
    has_public_ip
  end
  def has_service_ip?
    has_service_ip
  end
  def destroy_changed_ips
    if public_ip_address_id_was and public_ip_address_id_changed?
      ip = IpAddress.find(public_ip_address_id_was)
      ip.destroy if ip
    end
    if locale_ip_address_id_was and locale_ip_address_id_changed?
      ip = IpAddress.find(locale_ip_address_id_was)
      ip.destroy if ip
    end
  end
  def destroy_unused_ips
    public_ip_address.destroy if public_ip_address
    locale_ip_address.destroy if locale_ip_address
  end
end

class RampartService < ActiveRecord::Base
  belongs_to :rampart
  validates_presence_of :description
  validates_presence_of :network
  validates_uniqueness_of :rampart_id, :scope => [:network, :port, :direction, :protocol], :allow_nil => true,
    :message => 'already has a service like that!'
  has_paper_trail
end

class RampartServiceTemplate < ActiveRecord::Base
  has_paper_trail
end
