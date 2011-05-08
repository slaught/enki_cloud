class ClusterController < ApplicationController
  filter_access_to :all
  filter_access_to :add_service, :attribute_check => true do
    permitted_to!(:add_to_cluster, Service.find(params[:service][:service_id]))
  end
  filter_access_to :remove_service, :attribute_check => true do
    permitted_to!(:remove_from_cluster, Service.find(params[:service]))
  end
  verify :method => :post, :only => [:update, :create, :remove_service, :add_service ], :redirect_to => {:action => :list }
  
  def index
    redirect_to :action => "list"
  end
  def list
    @clusters = Cluster.find(:all,:order =>'cluster_name')
 @counts = @clusters.map {|c| 
        if c.active? then c.nodes.count + c.services.count else nil end 
   }.compact
  @max = @counts.max
  @sum = @counts.sum
  @avg = 1 
  @avg = @sum /@counts.length if @counts.length > 0
  @sparkline = "TopfunkySparkline('chart', 
                #{@counts.inspect},
                   {
                     width: #{@clusters.length * 2}, 
                     height: #{@max}, 
                     title:'The Cloud', 
                     target: #{@avg + 1}, 
                     good_threshold: 7 } );"
    respond_to do |format|
       format.html # index.html.erb
       format.tex  { render :tex => @clusters }
    end
  end
  def show
    @cluster = Cluster.find(params[:id])
    flash.now[:system_warning] = "This cluster has no assigned load balancers!" if @cluster.no_lb_assigned?
    respond_to do |format|
        format.html
        format.xml
    end
  end
  #def new
  # 
  #end
  def edit
    @cluster =  Cluster.find(params[:id])
    render 
  end
  def update 
    @cluster =  Cluster.find(params[:id])
    @cluster.attributes = params[:cluster]
   
    if @cluster.save
      flash[:notice] = "Cluster was successfully updated"
      redirect_to :action => "show", :id => @cluster
    else
      render :action => 'edit'
    end
  end
  def create
    @p = params[:cluster]
    begin
     @cluster = Cluster.create_cluster(@p[:cluster_name],@p[:description], @p[:vlan], @p[:ip_range], @p[:load_balanced])
      if not @cluster.nil? and @cluster.save
        flash[:notice] = 'Cluster was successfully created.'
        return redirect_to( :action => 'show', :id=> @cluster)
      end
    rescue NodeException => e
          flash.now[:warning] = "Error #{e.to_s}"
    rescue ActiveRecord::RecordNotFound => e
          flash.now[:warning] = "Missing Data: #{e.to_s}"
    end
    render :action => "new" 
  end 
  def remove_service
    modify_services(params[:service]) do |cs_exists,cluster,svc|
      if cs_exists then
        flash.now[:warning] = "Error no such service on cluster"
      else
        cluster.services.delete(svc)
      end
    end
  end
  def add_service
    modify_services(params[:service][:service_id]) do |cs_exists, cluster, svc| 
      if cs_exists then
        cluster.services << svc
      else
        flash.now[:warning] = "Error service in cluster"
      end
    end 
  end

  def remove_node
    
    modify_nodes(params[:node]) do |cs_exists, cluster, node|
      if cs_exists then 
        flash.now[:warning] = "Error no such node in cluster"
      else
        @cluster.nodes.delete(@node)
      end
    end
    #  render :partial => 'node_list', :locals => {:cluster=>@cluster, :nodes =>@cluster.nodes }
  end
  def add_node
    modify_nodes(params[:node][:node_id]) do |cs_exists, cluster, node|
      if cs_exists then 
        cluster.merge_node( node)
      else
        flash.now[:warning] = "Error node already in cluster"
      end
    end
  end

  def destroy
    c = Cluster.find params[:id]
    unless c.active? and c.cluster_services.empty? and c.cluster_nodes.empty?
      begin
        c.destroy
      rescue Exception => e
        flash[:warning] = "Error deleting cluster"
      end
      flash[:notice] = "Cluster Deleted!"
    else
      flash[:warning] = "Can not delete ACTIVE cluster"
    end

    redirect_to :action => "list"
  end

  private
  def modify_nodes(node_id, &block)
    @node = Node.find(node_id.to_i)

    @cluster = Cluster.find(params[:id].to_i)
    @cs = ClusterNode.find_by_node_id_and_cluster_id(@node.id,@cluster.id)
    yield @cs.nil?, @cluster, @node 
    render :partial => 'node_list', :locals => {:cluster=>@cluster, :nodes =>@cluster.nodes(true) }
  end
  private
  def modify_services( service_id, &block)
    @svc = Service.find(service_id.to_i)

    @cluster = Cluster.find(params[:id].to_i)
    @cs = ClusterService.find_by_service_id_and_cluster_id(@svc.id,@cluster.id)
    yield @cs.nil?, @cluster, @svc
    render :partial => 'service_list', :locals => {:cluster=>@cluster, :services=>@cluster.services}
  end
  
end
