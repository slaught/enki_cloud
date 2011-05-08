class BootstrapsController < ApplicationController
  filter_access_to :index, :clonenode, :show, :edit, :update, :destroy, :new, :stage_one, :stage_two, :ready
  # GET /bootstraps/ready/uuid
  # GET /bootstraps/ready/servicetag
  
  def ready
    check_ready(params)
  end
  def ready1 
    check_ready(params, 1)
  end
  def ready2 
    check_ready(params, 2)
  end

  @private 
  def check_ready(params, stage=nil)
    tag = params[:id]
    @bootstrap = Bootstrap.find_by_tag(tag) 
    if @bootstrap.nil? then
      render :text => "Did not found a valid host for:#{tag}\n",:status => 404
    elsif @bootstrap.ready?(stage) then 
      render :text => "reboot",:status => 200
    else
      render :text => "Not ready to reboot",:status => 307
    end
  end
  
  # POST /bootstraps/1/clonenode
  # PUT /bootstraps/1/clonenode
  def clonenode 
    @bootstrap = Bootstrap.find(params[:id])

    respond_to do |format|
      if @bootstrap.update_attributes(params[:bootstrap])
        flash[:notice] = 'Bootstrap was successfully updated.'
        format.html { redirect_to(@bootstrap) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @bootstrap.errors, :status => :unprocessable_entity }
      end
    end
  end


  # GET /bootstraps
  # GET /bootstraps.xml
  def index
    @bootstraps = Bootstrap.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @bootstraps }
    end
  end

  # GET /bootstraps/1
  # GET /bootstraps/1.xml
  def show
    @bootstrap = Bootstrap.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @bootstrap }
    end
  end

  # GET /bootstraps/new
  # GET /bootstraps/new.xml
  def new
    @bootstrap = Bootstrap.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @bootstrap }
    end
  end

  # GET /bootstraps/1/edit
  def edit
    @bootstrap = Bootstrap.find(params[:id])
  end

  # POST /bootstraps
  # POST /bootstraps.xml
  def create
    if params.has_key?('bootstrap') then
      @bootstrap = Bootstrap.new(params['bootstrap'])
    else
      @bootstrap = Bootstrap.create_from_post(params)
    end

    respond_to do |format|
      if @bootstrap.save
        flash[:notice] = 'Bootstrap was successfully created.'
        format.html { redirect_to(@bootstrap) }
        format.xml  { render :xml => @bootstrap, :status => :created, :location => @bootstrap }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @bootstrap.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /bootstraps/1
  # PUT /bootstraps/1.xml
  def update
    @bootstrap = Bootstrap.find(params[:id])

    respond_to do |format|
      if @bootstrap.update_attributes(params[:bootstrap])
        @bootstrap.process
        flash[:notice] = 'Bootstrap was successfully updated.'
        format.html { redirect_to(@bootstrap) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @bootstrap.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /bootstraps/1
  # DELETE /bootstraps/1.xml
  def destroy
    @bootstrap = Bootstrap.find(params[:id])
    @bootstrap.destroy

    respond_to do |format|
      format.html { redirect_to(bootstraps_url) }
      format.xml  { head :ok }
    end
  end
end
