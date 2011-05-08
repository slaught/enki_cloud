class DatabaseConfigsController < ApplicationController
#      filter_resource_access                                                                                          
  filter_access_to :update, :create, :new, :edit, :show, :destroy 
#  verify :method => :post, :only => [:update, :create ], :redirect_to => {:action => :list }

  # GET /database_configs
  # GET /database_configs.xml
  def index
    @database_configs = DatabaseConfig.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @database_configs }
    end
  end

  # GET /database_configs/1
  # GET /database_configs/1.xml
  def show
    @database_config = DatabaseConfig.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @database_config }
    end
  end

  # GET /database_configs/new
  # GET /database_configs/new.xml
  def new
    @database_config = DatabaseConfig.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @database_config }
    end
  end

  # GET /database_configs/1/edit
  def edit
    @database_config = DatabaseConfig.find(params[:id])
  end

  # POST /database_configs
  # POST /database_configs.xml
  def create
    @database_config = DatabaseConfig.new(params[:database_config])

    respond_to do |format|
      if @database_config.save
        flash[:notice] = 'DatabaseConfig was successfully created.'
        format.html { redirect_to(@database_config) }
        format.xml  { render :xml => @database_config, :status => :created, :location => @database_config }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @database_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /database_configs/1
  # PUT /database_configs/1.xml
  def update
    @database_config = DatabaseConfig.find(params[:id])

    respond_to do |format|
      if @database_config.update_attributes(params[:database_config])
        flash[:notice] = 'DatabaseConfig was successfully updated.'
        #format.html { redirect_to(database_configs_url) }
        format.html { redirect_to(@database_config) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @database_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /database_configs/1
  # DELETE /database_configs/1.xml
  def destroy
    @database_config = DatabaseConfig.find(params[:id])
    @database_config.destroy

    respond_to do |format|
      format.html { redirect_to(database_configs_url) }
      format.xml  { head :ok }
    end
  end
end
