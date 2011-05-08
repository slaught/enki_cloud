class NetworksController < ApplicationController
  include CNU::Conversion
  filter_access_to :all
  verify :method => :delete, :only =>[ :destroy1 ], :redirect_to => { :action => :new  },
    :add_flash => { "alert" => "delete is required to destroy" }
  verify :method => :post, :only => [ :create ], 
    :redirect_to => {:action => :list },
    :add_flash => { "alert" => "post is required to create" }
  verify :method => [:post, :put], :only => [:update] , 
    :add_flash => { "alert" => "update is only post or put" },
    :redirect_to => {:action => :list }

  # GET /networks
  # GET /networks.xml
  def index
    @networks = Network.all.sort_by{|n| ip2dec(ip(n.ip_range))}

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @networks }
    end
  end

  # GET /networks/1
  # GET /networks/1.xml
  def show
    @network = Network.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @network }
    end
  end

  # GET /networks/new
  # GET /networks/new.xml
  def new
    @network_types = NetworkType.all
    @network = Network.new
   # unless params[:network_type].blank?
   #   @network.network_type = NetworkType.find_by_name(params[:network_type]) 
   # end
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @network }
    end
  end

  # GET /networks/1/edit
  def edit
    @network = Network.find(params[:id])
      @network_types = NetworkType.all
  end

  # POST /networks
  # POST /networks.xml
  def create
    @p = params[:network]
    failed = false
    begin
      nt = @p[:network_type_id].to_i
      @network = Network.new(@p)
      @network_types = NetworkType.all
    rescue 
      failed = true
    end
    respond_to do |format|
      if (! failed ) && @network.save
        format.html { redirect_to( @network, :notice => 'Network was successfully created.') }
        format.xml  { render :xml => @network, :status => :created, :location => @network }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @network.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /networks/1
  # PUT /networks/1.xml
  def update
    @network = Network.find(params[:id])
    @network_types = NetworkType.all

    respond_to do |format|
      if @network.update_attributes(params[:network])
        format.html { redirect_to(@network, :notice => 'Network was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @network.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /networks/1
  # DELETE /networks/1.xml
  def destroy
    @network = Network.find(params[:id])
    @network.destroy

    respond_to do |format|
      format.html { redirect_to(networks_url) }
      format.xml  { head :ok }
    end
  end
end
