
class SoftwareController < ApplicationController
  filter_access_to :all
  verify :method => :post, :only => [:update, :create], :redirect_to => {:action => :list }

  def index
    redirect_to :action => "list"
  end

  def list
    @distributions = Distribution.find :all
    #@osversions = OsVersion.find :all
  end

  def edit
    @osversion = OsVersion.find(params[:id])
  end

  def edit_dist
    @distribution = Distribution.find(params[:id])
  end

  def update
    @osversion = OsVersion.find(params[:id])
    if @osversion.update_attributes(params[:osversion])
      flash[:notice] = 'Os Version successfully updated.'
 
      redirect_to :action => 'edit', :id => @osversion
    else
      render :action => 'edit'
    end
  end

  def update_dist
    @distribution = Distribution.find(params[:id])
    if @distribution.update_attributes(params[:distribtution])
      flash[:notice] = 'Distribution successfully updated.'

      redirect_to :action => 'list'
    else
      render :action => 'edit'
    end
  end

  def new
    @osversion = OsVersion.new
  end

  def new_dist
    @distribution = Distribution.new
  end

  def create
    @p = params[:osversion]

    begin
      @osversion = OsVersion.new
      @osversion.distribution = @p[:distribution]
      @osversion.kernel = @p[:kernel]

      if @osversion.save()
        flash[:notice] = 'Os Version was sucessfully created.'
        return redirect_to( :action => 'list' )
      else
        flash.now[:warning] = "There was a problem saving your Os Version"
      end
      
    rescue ActiveRecord::RecordNotFound => e
      flash.now[:warning] = "Missing Data: #{e.to_s}"
    end
    
    render :action => "new"
  end
  
  def create_dist
    @p = params[:distribution]
    begin
      @distribution = Distribution.new
      @distribution.name = @p[:name]

      if @distribution.save()
        flash[:notice] = 'Distribution was successfully created.'
        return redirect_to( :action => 'list' )
      end

    rescue ActiveRecord::RecordNotFound => e
      flash[:warning] = "Missing Data: #{e.to_s}"
    end
  
    render :action => "new_dist"
  end
end
