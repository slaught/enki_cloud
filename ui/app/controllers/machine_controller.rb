require 'network_nodes'
class MachineController < ApplicationController
  filter_access_to :all
  verify :method => :post, :only => [:update, :create], :redirect_to => {:action => :list }

  def index
    redirect_to :action => 'list'
  end
  def list
    @machines = CnuMachineModel.find(:all)
    render 
  end
  def show
    @machine = CnuMachineModel.find(params[:id].to_i)
    render 
  end
  def edit
    @machine = CnuMachineModel.find(params[:id].to_i)
    render 
  end
  def update 
    @machine = CnuMachineModel.find(params[:id].to_i)
    @machine.update_attributes(params[:machine])
    if @machine.save
        flash[:notice] = "Machine was successfully updated"
        redirect_to :action => "show", :id => @machine
    else
      render :action => :edit 
    end
  end
  def create
    @p = params[:machine]
    begin
     @m = CnuMachineModel.create(@p)
      if not @m.nil? and @m.save
        flash[:notice] = 'Machine was successfully created.'
        return redirect_to( :action => 'show', :id=> @m)
      end
    rescue ActiveRecord::RecordNotFound => e
          flash.now[:warning] = "Missing Data: #{e.to_s}"
    end
    render :action => "new" 
  end 



end

