module  ClusterHelper
  def potential_services(cluster)
    services = Service.addable - cluster.services
    services.select{|s| permitted_to? :add_to_cluster, s}
  end

  def last_octet(i)
    ip(i).split('.')[-2] + '.' +  ip(i).split('.')[-1]
  end
end


