module XenHelper
  def potential_guests
    XenMapping.unassigned.select{|n| n.datacenter == @host.datacenter}
  end
end
