module NetworksHelper
  # TODO: remove ramparts stuff once they get integrated properly into rest of system
  def all_locale_ramparts
    Rampart.all.select{|r| r.locale_ip_address and r.locale_ip_address.network == @network}
  end
  def all_public_ramparts
    Rampart.all.select{|r| r.public_ip_address and r.public_ip_address.network == @network}
  end
  def add_done_ips(ips)
    @done_ips = [] if not defined?(@done_ips)
    (@done_ips << ips).flatten!
    @other = true
    # @other_ips = IpAddress.find_by_network_id(@network.id) - remove
  end
  def get_other_ips
    all_ips = IpAddress.find_all_by_network_id(@network.id)
    defined?(@done_ips) ? (all_ips - @done_ips) : all_ips
  end
end
