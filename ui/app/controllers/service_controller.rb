
class ServiceController < ApplicationController
  include CNU::Parsers
  filter_access_to :all
  verify :method => :post, :only => [:update, :create ], :redirect_to => {:action => :list }
  
  def index
    redirect_to :action => "list"
  end
  def list
    case params[:id]
    when "public"
      @services = Service.find(:all,:order => 'name', :conditions => ["availability = ?", "public"])
    when "campus"
      @services = Service.find(:all,:order => 'name', :conditions => ["availability = ?", "campus"])
    else
      @services = Service.find(:all,:order => 'name')
    end
    respond_to do |format|
      format.html { render }
      format.json { render :json =>  @services.to_json }
    end
  end
  def listjson
    q = params[:q]      
    if not q.nil? and q.length > 0 then 
      @services = Service.addable.find(:all, :conditions => ["name like ?","%#{q}%"]) 
    else
      @services = Service.addable # find(:all, :conditions =>["ip_address is not null"],:order => :name) 
    end
    data = @services.map {|x| { "id"=> x.service_id, "name"=> x.to_label} } 
    render :json => { :results => data }.to_json 
  end
  def show
    @service = Service.find(params[:id])
    render 
  end
  def show_name
    #serviceArray = Service.find_all_by_name(params[:id])
    # HACK HACK HACK HACK HACK
    serviceArray = Service.find_all_by_ip_address(Service.find_by_name(params[:id]).ip_address, :order => 'name')
    if serviceArray.length < 1
      #TODO: change to WARNING
      flash[:warning] = "No entries found with sepcified name!"
      redirect_to :action => "list"
    elsif serviceArray.length == 1
      @service = serviceArray[0]
      redirect_to :action => "show", :id => @service
    else
      @services = serviceArray
      render :action => :list
    end
  end
    #    def destroy
    #      Entry.find(params[:id]).destroy
    #      redirect_to :action => "list"
    #    end
   def new
     @service = Service.new
     render
   end
   def create
     svc = params[:service]      
     @service = nil
     error = nil
     begin
       @service = Service.create_service(svc)
       @service.save
     rescue ActiveRecord::StatementInvalid => e
       @service.errors.add(:local_port, ": #{get_pgerror(e)}")
     end
     if @service.errors.empty?
        flash[:notice] = "Service was successfully created"
        redirect_to :action => "show", :id => @service
     else
        render :action => :new
     end
   end
   def edit
      @service = Service.find(params[:id].to_i)
      render 
   end
   def update
#  Parameters: {"commit"=>"Update", "protocol"=>{"protocol_id"=>"2"},
#  "service"=>{"name"=>"radius", "local_port"=>"", "service_port"=>"1812",
#  "url"=>"radius://radius.example.com", "ip_address"=>"1.1.2.21"}, "action"=>"update", "id"=>"33", "controller"=>"service"}
     @service = Service.find(params[:id])
     begin
       @service.update_attributes(params[:service])
     rescue ActiveRecord::StatementInvalid => e
       @service.errors.add(:local_port, ": #{get_pgerror(e)}")
     end
     if @service.errors.empty?
        flash[:notice] = "Service was successfully updated"
        redirect_to :action => "show", :id => @service
     else
        render :action => :edit
    end
  end

  def add_dependency_form
    @service = Service.find params[:id]
    render :partial => "adddependency"
  end

  def add_dependency

    @service = Service.find(params[:service][:id])
    @dependency = Service.find(params[:dependency][:id])

    service_dependency = ServiceDependency.new
    service_dependency.parent = @service  
    service_dependency.child = @dependency
    
    begin
      if service_dependency.save
        flash[:notice] = "Service Dependency was successfully added"
        redirect_to :action => "show", :id => @service
      else
        flash[:warning] = "There was a problem adding your dependency!"
        redirect_to :action => "show", :id => @service
      end
    rescue => e
        flash[:warning] = ["There was a big error while adding your dependency!"]
        flash[:warning] << "<br/>"
        flash[:warning] << e
        redirect_to :action => "show", :id => @service
    end
  end

  def del_dependency
    begin
      @dependency = ServiceDependency.find(params[:id])
      @service = @dependency.parent
      @dependency.destroy
    rescue
      flash[:warning] = "There was a problem removing the dependency. Sorry."
    else
      flash[:notice] = "The dependency was successfully removed! Yay!"
    end
    redirect_to :action => "show", :id => @service
  end
end
__END__
##########################3

