class NilClass
      def dup
         self
      end
end
class XenController < ApplicationController
  filter_access_to :all
  helper_method :all_guests_for
  #helper_method :live_map

  def list
    @nodes = XenMapping.find(:all, :order => 'host_id')
    respond_to do |format|
        format.html
        format.xml { 
            @nodes = XenMapping.find(:all, :select => "DISTINCT(host_id)").map! { |h| h.host }
            
            render
        }
    end
  end

  def destroy
    id = params[:id].to_i
    xen = XenMapping.find(id)
    xen.destroy
    redirect_to :action => 'list'
  end
  def new
    @xen_mapping = XenMapping.new
  end
  def create
      host_id = params[:xen_mapping][:host_id].to_i
      guest_id = params[:xen_mapping][:guest_id].to_i
      begin
        @xen = XenMapping.move_guest(Node.find(host_id),Node.find(guest_id))
        if @xen.save
          flash[:notice] = 'Mapping was successfully created.'
          redirect_to :action => 'list'
          return
        end
      rescue Exception => e
          flash.now[:warning] = "Error : #{e.to_s}"
       @errors = {"Failed" => e.to_s}
      end
      render :action => "new"
  end

  # ####### for the compare page ########
  #
  def compare
    #XenMapping.find :all
    @nodes = Datacenter.all.map do |d| 
      [d.name, Node.in_datacenter(d).dom0s.uniq.map{|domo|
        [domo, (domo.domus | domo.live_domus).sort{|x,y| x.to_label <=> y.to_label}]}]
    end
    
    #@nodes = [["Abc", Node.in_datacenter("abc").dom0s.uniq.map{|domo|
    #    [domo, (domo.domus | domo.live_domus).sort{|x,y| x.to_label <=> y.to_label}]}]]
    


    #@nodes = [Node.find(580)]
  end

  def map_to_host
    @host = Node.find(params[:host_id])
    guest = Node.find_by_fn_prefix(params[:guest_fn_prefix])
    old_dom0 = guest.xen_domO if not guest.xen_domO.blank?

    begin
      @xen = XenMapping.move_guest(@host,guest)
      @xen.save
    rescue Exception => e
      show_error "Error : #{e.to_s}"
      return
    end

    domo = @host
    guests = (domo.domus | domo.live_domus).sort{|x,y| x.to_label <=> y.to_label}

    Rcache.clear("#{domo.to_label}-mapping-table")

    render :update do |page|
      page.replace_html "#{@host.to_label}", :partial => 'xen_host_map',
        :locals => {:domo => domo, :guests => guests }
      page.hide "#{@host.to_label}_add_mapping_form"
      unless old_dom0.blank?
        Rcache.clear("#{old_dom0}-mapping-table")

        o_guests = (old_dom0.domus | old_dom0.live_domus).sort{|x,y| x.to_label <=> y.to_label}

        page.replace_html "#{old_dom0.to_label}", :partial => 'xen_host_map',
        :locals => {:domo => old_dom0, :guests => o_guests }
      page.hide "#{old_dom0.to_label}_add_mapping_form"
      end
    end
  end

  def add_new_mapping
    @host = Node.find(params[:host_id])
    guest = Node.find(params[:xen_mapping][:guest_id])
    begin
      xen = XenMapping.add_guest(@host,guest)
      xen.save
    rescue Exception => e
      show_error "Error : #{e.to_s}"
      return
    end

    domo = @host
    guests = (domo.domus | domo.live_domus).sort{|x,y| x.to_label <=> y.to_label}

    Rcache.clear("#{domo.to_label}-mapping-table")

    render :update do |page|
      page.replace_html "#{@host.to_label}", :partial => 'xen_host_map',
        :locals => {:domo => domo, :guests => guests }
      page.hide "#{@host.to_label}_add_mapping_form"
    end
  end

  def unmap_guest
    @host = Node.find(params[:host_id])
    guest = Node.find_by_fn_prefix(params[:guest_fn_prefix])
    begin
      XenMapping.remove_guest(guest)
    rescue Exception => e
      show_error "Error : #{e.to_s}"
      return
    end

    domo = @host
    guests = (domo.domus | domo.live_domus).sort{|x,y| x.to_label <=> y.to_label}

    Rcache.clear("#{domo.to_label}-mapping-table")

    render :update do |page|
      page.replace_html "#{@host.to_label}", :partial => 'xen_host_map',
        :locals => {:domo => domo, :guests => guests }
      page.hide "#{@host.to_label}_add_mapping_form"
    end
  end

  def show_add_mapping_form
    @host = Node.find(params[:host_id])
    show_form
  end

  def hide_add_mapping_form
    @host = Node.find(params[:host_id])
    render :update do |page|
      page.hide "#{@host.to_label}_add_mapping_form"
      page.replace "#{@host.to_label}_toggle_add_mapping_form_button",
        :partial => "show_add_mapping_form_button", :locals => {:host => @host}
    end
  end



private
  def show_error(error_message)
    flash.now[:error] = error_message
    show_form true
  end

  def show_form(refresh_host_mappings=false)
    render :update do |page|
      if refresh_host_mappings
        domo = @host
        guests = (domo.domus | domo.live_domus).sort{|x,y| x.to_label <=> y.to_label}
        page.replace_html "#{@host.to_label}", :partial => 'xen_host_map',
          :locals => {:domo => @host, :guests => guests}
      end
      page.show "#{@host.to_label}_add_mapping_form"
      page.replace_html "#{@host.to_label}_add_mapping_form", :partial => "add_mapping"
      page["#{@host.to_label}_add_mapping_form"].removeClassName('hidden')
      page.replace "#{@host.to_label}_toggle_add_mapping_form_button",
        :partial => "hide_add_mapping_form_button", :locals => {:host => @host}
    end
  end

  def all_guests_for(host)
    xen_compare(host.xen_guests.map{|g| g.guest.to_label}, (live_map[host.to_label] or []))
  end

  # takes two arrays of domUs
  # conf = ["bob01.abc", "joe02.abc", "sam03.abc"]
  # live = ["bob01.abc", "joe02.abc", "jane03.abc"]
  # returns an array of three sorted arrays (conf, live, combo)
  # [
  #   [ "bob01.abc", "", "joe02.abc", "sam03.abc"],
  #   [ "bob01.abc", "jane03.abc", "joe02.abc", ""],
  #   [ "bob01.abc", "jane03.abc", "joe02.abc", "sam03.abc"]
  # ]
  def xen_compare(conf, live)
    combo = conf | live
    combo.sort!

    conf_ret = combo.map{ |n|
      if conf.include?(n)
        n
      else
        nil
      end
    }

    live_ret = combo.map{ |n|
      if live.include?(n)
        n
      else
        nil
      end
    }

    [conf_ret, live_ret, combo]

  end

  def live_map
    if session[:live_map].blank?
      session[:live_map] = XenMapping.get_live_mappings
    end
    session[:live_map]
  end
end
