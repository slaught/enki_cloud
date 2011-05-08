class DatabaseClustersController < ApplicationController
  filter_access_to :all
#  filter_access_to :update, :create, :new, :edit, :show, :destroy 
  verify :method => :post, :only => [:create, :add_database, :remove_database], :redirect_to => {:action => :list }
  verify :method => [:post, :put], :only => :update , :redirect_to => {:action => :list }
  def index
    @database_clusters = DatabaseCluster.find(:all)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @database_clusters }
      format.yaml  { render :yaml => @database_clusters }
    end
  end
  def config
    @database_cluster = DatabaseCluster.find(params[:id])
    template = "database_clusters/config#{@database_cluster.version.to_s.sub('.','')}"
    render :template => template, :layout => false
    #respond_to do |format|
    #  format.html {  render :file => template }
    #  format.xml  { render :xml => @database_cluster }
    #end
  end
  def show
    @database_cluster = DatabaseCluster.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @database_cluster }
    end
  end
  def new
    @database_cluster = DatabaseCluster.new
    @services = Service.find(:all, :conditions => ["url like 'postgresql%%'"], :order => :name)
    @database_configs = DatabaseConfig.all
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @database_cluster }
    end
  end
  def edit
    @database_cluster = DatabaseCluster.find(params[:id])
    @services = Service.find(:all, :conditions => ["url like 'postgresql%%'"], :order => :name)
    @database_configs = DatabaseConfig.all
  end

  def create
    @service = Service.find(params[:database_cluster][:service_id]) 
    @database_cluster = DatabaseCluster.new(params[:database_cluster].merge({:service_id => @service.id}))
    @services = Service.find(:all, :conditions => ["url like 'postgresql%%'"], :order => :name)
    @database_configs = DatabaseConfig.all

    respond_to do |format|
      if @database_cluster.save
        flash[:notice] = 'DatabaseCluster was successfully created.'
        format.html { redirect_to(@database_cluster) }
        format.xml  { render :xml => @database_cluster, :status => :created, :location => @database_cluster }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @database_cluster.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @database_cluster = DatabaseCluster.find(params[:id])

    respond_to do |format|
      if @database_cluster.update_attributes(params[:database_cluster])
        flash[:notice] = 'DatabaseCluster was successfully updated.'
        #format.html { redirect_to(database_clusters_url) }
        format.html { redirect_to(@database_cluster) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @database_cluster.errors, :status => :unprocessable_entity }
      end
    end
  end
  def destroy
    @database_cluster = DatabaseCluster.find(params[:id])
    if not @database_cluster.database_names.empty?   
      @database_cluster.database_name.delete
    end
    @database_cluster.destroy

    respond_to do |format|
      format.html { redirect_to( database_clusters_url) }
      format.xml  { head :ok }
    end
  end
  def add_database
    modify(params[:database_name][:database_name_id]) do |cs_exists,listof,item|
      if cs_exists then
        listof << item
      else
        flash[:warning] = "Error database_name in cluster"
      end
    end
  end
  def remove_database
#    modify_services(params[:service]) do |cs_exists,cluster,svc|
    modify(params[:database_name]) do |cs_exists,listof,item|
      if cs_exists then
        flash[:warning] = "Error no such service on cluster"
      else
        listof.delete(item)
      end
    end
  end

  private
  def modify(database_name_id, &block)
    @dbn = DatabaseName.find(database_name_id.to_i)
    @cluster = DatabaseCluster.find(params[:id].to_i)
    @cs = DatabaseClusterDatabaseName.find_by_database_cluster_id_and_database_name_id(@cluster.id, @dbn.id)
    yield @cs.nil?, @cluster.database_names, @dbn
    render :partial => 'database_list', :locals => {:database_cluster=>@cluster, 
            :database_names => @cluster.database_names(true) }
# <% # :locals => {:database_names => @database_cluster.database_names, :database_cluster =>@database_cluster } %>
  end
end
