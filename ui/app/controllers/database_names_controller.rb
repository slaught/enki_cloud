class DatabaseNamesController < ApplicationController
#  filter_access_to :all
  filter_access_to :update, :create, :new, :edit, :show, :destroy 
  def index
    @database_names = DatabaseName.find(:all)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @database_names }
    end
  end
  def show
    @database_name = DatabaseName.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @database_name }
    end
  end
  def new
    @database_name = DatabaseName.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @database_name }
    end
  end
  def edit
    @database_name = DatabaseName.find(params[:id])
  end
  def create
    @database_name = DatabaseName.new(params[:database_name])

    respond_to do |format|
      if @database_name.save
        flash[:notice] = 'DatabaseName was successfully created.'
        format.html { redirect_to(database_names_url) }
        format.xml  { render :xml => @database_name, :status => :created, :location => @database_name }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @database_name.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @database_name = DatabaseName.find(params[:id])

    respond_to do |format|
      if @database_name.update_attributes(params[:database_name])
        flash[:notice] = 'DatabaseName was successfully updated.'
        #format.html { redirect_to(database_names_url) }
        format.html { redirect_to(@database_name) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @database_name.errors, :status => :unprocessable_entity }
      end
    end
  end
  def destroy
    @database_name = DatabaseName.find(params[:id])
    if @database_name.database_clusters.empty? then
      @database_name.destroy
    else
        flash[:warning] = 'DatabaseName is still used.'
    end
    respond_to do |format|
      format.html { redirect_to( database_names_url) }
      format.xml  { head :ok }
    end
  end
end
