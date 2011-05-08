class SanController < ApplicationController
  filter_access_to :all
  verify :method => :post, :only => [:update, :create, :add_node, :remove_node], :redirect_to => {:action => :list }

  def index
    redirect_to :action => 'list'
  end
  def list
    @sans = San.find(:all,:order =>'san_name')
    render 
  end
  def show
    @san = San.find(params[:id])
    render 
  end
  def new
    @san = San.new
    @networks = San.available_networks
    render 
  end
  def edit
    @san =  San.find(params[:id])
    @networks = San.available_networks
    render 
  end
  def update 
    @san =  San.find(params[:id])
    @networks = San.available_networks
    if @san.update_attributes(params[:san])
      flash[:notice] = 'San was successfully updated.'
        redirect_to :action => 'show', :id=> @san
    else
        render :edit
    end 
  end
  def create
    @p = params[:san]
    begin
     @san = San.create(@p)
     @networks = San.available_networks
      if not @san.nil? and @san.save
        flash[:notice] = 'San was successfully created.'
        return redirect_to( :action => 'show', :id=> @san)
      end
    rescue NodeException => e
          flash.now[:warning] = "Error #{e.to_s}"
    rescue ActiveRecord::RecordNotFound => e
          flash.now[:warning] = "Missing Data: #{e.to_s}"
    end
    render :action => "new" 
  end 
  def remove_node
    modify_nodes(params[:node]) do | san, node|
        san.remove_node(node)
    end
    #  render :partial => 'node_list', :locals => {:cluster=>@cluster, :nodes =>@cluster.nodes }
  end
  def add_node
    modify_nodes(params[:node][:node_id]) do | san, node|
      if san.empty_interfaces(node) > 0 then 
        x =  san.add_node(node)
        flash.now[:warning] = "No San interfaces added for Node." if x.length == 0
      else
        if node.san_nics.length > 0 then
          flash.now[:warning] = "Error node already connected to san"
        else
          flash.now[:warning] = "Error node has no nics "
        end
      end
    end
  end

  private
  def modify_nodes(node_id, &block)
    @san= San.find(params[:id].to_i)
    @node = Node.find(node_id.to_i)
    if @node.nil? or @san.nil? then 
    raise Exception.new(" node or san nil ")
    end
    yield  @san, @node 
    render :partial => 'node_list', :locals => {:san=>@san, :nodes =>@san.san_nodes }
  end

end
