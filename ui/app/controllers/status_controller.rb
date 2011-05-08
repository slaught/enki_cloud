class StatusController < ApplicationController
  #filter_access_to :all
  #verify :method => :post, :only => [:update, :create, :remove_service, :add_service ], :redirect_to => {:action => :list }
  def cluster
    base_data
    @clusters = []
    @portfwd = []
    Cluster.find(:all, :order => :cluster_name).each {|c|
        next unless c.active?
        if c.load_balanced? then
          if c.cluster_name !~ /backend/ 
            @clusters <<  json_fmt(c)
          end
        else
          @portfwd << json_fmt(c)
        end
    }
    z = @active_load_balancers.map { |lb| [lb.fqdn, lb.datacenter.name] }.flatten
    @lbs = Hash[*z]
    @data = [{"load_balancers"=> @lbs}].concat(@clusters).concat( @portfwd)
    render :layout => false
  end
  private
  def json_fmt(c,include_all=false)
     h =  { 'cluster_id' => "c#{c.cluster_id}",
       "fw_mark" => "#{c.fw_mark }",
        "link"   => "#{ lb_fullurl( c ) }",
      "description" =>  "#{ c.description }", 
      "cluster_name" => "#{ c.cluster_name }"
      }
      if c.load_balanced? then 
        h["kindof"] =  "load balanced"
      else 
        h["kindof"] = "port forward"
      end
      s  = c.services.map {|s| s if s.has_downpage? }.compact.each do |service|  
        { "ha_hostname" => "#{ service.ha_hostname }", "url" => "#{service.url }" }
      end
      h["services" ] = s
      n = c.nodes.map do |node| 
          next if node.is_load_balancer? 
          if include_all or @active_colos.member? node.datacenter then
          {
          "datacenter_name" => "#{ node.datacenter.name }",
          "ip_address" => "#{ ip(node.ip_address).to_s + ":0" }",
          "mgmt_ip_address" => "#{ ip(node.mgmt_ip_address) }",
          "status_url"  => "http://#{ ip(node.mgmt_ip_address) }/status",
          "link"   => "#{ lb_fullurl( node ) }",
          "hostname" => "#{ node.to_label }"
          }
          end
      end 
     h["nodes"] = n.compact
     h
  end
  private 
  def base_data
    @clusters = Cluster.find_all_active
    nutlb = Node.find_all_load_balancers(Datacenter.nut)
    obrlb = Node.find_all_load_balancers(Datacenter.obr)
    @all_load_balancers  = [nutlb , obrlb].flatten
    if params[:q] =~ /obr/ then
      @active_colos = [ Datacenter.obr ] 
      @other_colos = Datacenter.all 
      @other_colos.delete( Datacenter.obr )
      @active_load_balancers = obrlb
    else
      @active_colos = Datacenter.find_all_by_active(true);
      @other_colos = Datacenter.find_all_by_active(false);
      @active_load_balancers = nutlb
      @active_load_balancers = @active_colos.map{|colo| Node.find_all_load_balancers(colo) }.flatten
    end 
  end
  
end
