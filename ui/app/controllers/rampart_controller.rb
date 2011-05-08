class RampartController < ApplicationController
  include CNU::Parsers
  filter_access_to :all
  verify :method => :post, :only => [:update, :create], :redirect_to => {:action => "list"}

  def index
    redirect_to :action => "list"
  end
  
  def list
    @ramparts = Rampart.find(:all).sort_by{|r| r.node.to_label}
  end

  def show
    @rampart = Rampart.find(params[:id])
  end

  def new
    @rampart = Rampart.new
  end

  def create
    begin
      if params[:rampart][:has_service_ip].to_i == 1
        params[:rampart][:locale_ip_address_id] = Rampart.locale_network.next_ip.id
      end
      if params[:rampart][:has_public_ip].to_i == 1
        params[:rampart][:public_ip_address_id] = Rampart.public_network.next_ip.id
      end
      @rampart = Rampart.new(params[:rampart])
      return render :action => "new" if !@rampart.save
    rescue Exception => e
      flash[:error] = e.message
      redirect_to :action => "new" and return
    end

    flash[:notice] = "Rampart was successfully created."
    redirect_to :action => "edit", :id => @rampart
  end

  def edit
    @rampart = Rampart.find(params[:id])
  end

  def update
    @rampart = Rampart.find(params[:id])

    # find/create and save ip addresses
    if permitted_to? :manage_rampart_ip, :rampart
      if params[:rampart][:has_public_ip].to_i == 1 and not params[:rampart][:public_ip_address].blank?
        public_ip_field = params[:rampart][:public_ip_address]
        (final_ip, public_prefix_changed) = process_ip_input(public_ip_field, Rampart.public_network) 
        if final_ip.nil?
          @rampart.errors.add(:public_ip_address, "is not a valid ip address") and return render :action => 'edit'
        end
        public_ip = IpAddress.find_by_ip_address(final_ip)
        if @rampart.public_ip_address.nil? or @rampart.public_ip_address != public_ip
          begin
            public_ip = IpAddress.create(:ip_address => final_ip, :network_id => Rampart.public_network.id)
          rescue ActiveRecord::StatementInvalid => e
            @rampart.errors.add(:public_ip_address, "error: #{get_pgerror(e)}")
          else
            @rampart.errors.add_to_base("public #{public_ip.errors.full_messages}") if public_ip.invalid?
          end
        end
        params[:rampart][:public_ip_address_id] = public_ip.id if public_ip
      else
        params[:rampart][:public_ip_address_id] = nil
      end
      params[:rampart].delete(:public_ip_address)

      if params[:rampart][:has_service_ip].to_i == 1 and not params[:rampart][:locale_ip_address].blank?
        locale_ip_field = params[:rampart][:locale_ip_address]
        (final_ip, locale_prefix_changed) = process_ip_input(locale_ip_field, Rampart.locale_network)
        if final_ip.nil?
          @rampart.errors.add(:locale_ip_address, "is not a valid ip address") and return render :action => 'edit'
        end
        locale_ip = IpAddress.find_by_ip_address(final_ip)
        if @rampart.locale_ip_address.nil? or @rampart.locale_ip_address != locale_ip
          begin
            locale_ip = IpAddress.create(:ip_address => final_ip, :network_id => Rampart.locale_network.id)
          rescue ActiveRecord::StatementInvalid => e
            @rampart.errors.add(:locale_ip_address, "error: #{get_pgerror(e)}")
          else
            @rampart.errors.add_to_base("Locale #{locale_ip.errors.full_messages}") if locale_ip.invalid?
          end
        end
        params[:rampart][:locale_ip_address_id] = locale_ip.id if locale_ip
      else
        params[:rampart][:locale_ip_address_id] = nil
      end
      params[:rampart].delete(:locale_ip_address)
    end

    return render :action => "edit" if not @rampart.errors.empty?
    @rampart.update_attributes(params[:rampart])
    return render :action => "edit" if !@rampart.save

    flash[:notice] = 'Rampart was successfully updated.'
    flash[:notice] << "Changed netmask to /#{cidr_mask(Rampart.locale_network.ip_range)} matching the locale network." if locale_prefix_changed
    flash[:notice] << "Changed netmask to /#{cidr_mask(Rampart.public_network.ip_range)} matching the public network." if public_prefix_changed
    redirect_to :action => "list"
  end

  def get_public_ip
    @rampart = Rampart.find(params[:id])
    begin
      if params[:checked] =~ /^f/i
        success_message = 'ip deleted'
        @rampart.has_public_ip = false
        @rampart.public_ip_address = nil
        ip_id = nil
      else
        success_message = 'ip saved'
        @rampart.has_public_ip = true
        @rampart.public_ip_address = Rampart.public_network.next_ip
        ip_id = @rampart.public_ip_address.id
      end
      if not @rampart.save
        return render_rjs_update_fail('rampart_public_ip_address', @rampart.public_ip_address || '-',
          "Problem saving ip: #{@rampart.errors.full_messages.join(' ')}", ip_id)
      end
    rescue Exception => e
      return render_rjs_update_fail('rampart_public_ip_address', @rampart.public_ip_address || '-',
        "Problem saving ip: #{e.message}", ip_id)
    end
    render_rjs_update_success('rampart_public_ip_address', @rampart.public_ip_address || '-',
      success_message, ip_id)
  end
  def get_locale_ip
    @rampart = Rampart.find(params[:id])
    begin
      if params[:checked] =~ /^f/i
        success_message = 'ip deleted'
        @rampart.has_service_ip = false
        @rampart.locale_ip_address = nil
        ip_id = nil
      else
        success_message = 'ip saved'
        @rampart.has_service_ip = true
        @rampart.locale_ip_address = Rampart.locale_network.next_ip
        ip_id = @rampart.locale_ip_address.id
      end
      if not @rampart.save
        return render_rjs_update_fail('rampart_locale_ip_address', @rampart.locale_ip_address || '-',
          "Problem saving ip: #{@rampart.errors.full_messages.join(' ')}", ip_id)
      end
    rescue Exception => e
      return render_rjs_update_fail('rampart_locale_ip_address', @rampart.locale_ip_address || '-',
        "Problem saving ip: #{e.message}", ip_id)
    end
    render_rjs_update_success('rampart_locale_ip_address', @rampart.locale_ip_address || '-',
      success_message, ip_id)
  end  
  def get_public_ip_editable
    @rampart = Rampart.find(params[:id])
    begin
      @rampart.has_public_ip = true
      @rampart.public_ip_address = Rampart.public_network.next_ip
      ip_id = @rampart.public_ip_address.id
      if not @rampart.save
        return render_rjs_update_fail('rampart_public_ip_address', @rampart.public_ip_address,
          "Problem saving ip: #{@rampart.errors.full_messages.join(' ')}", ip_id, true)
      end
    rescue Exception => e
      return render_rjs_update_fail('rampart_public_ip_address', @rampart.public_ip_address,
        "Problem saving ip: #{e.message}", ip_id, true)
    end
    render_rjs_update_success('rampart_public_ip_address', @rampart.public_ip_address,
      'ip saved', ip_id, true)
  end
  def get_locale_ip_editable
    @rampart = Rampart.find(params[:id])
    begin
      @rampart.has_service_ip = true
      @rampart.locale_ip_address = Rampart.locale_network.next_ip
      ip_id = @rampart.locale_ip_address.id
      if not @rampart.save
        return render_rjs_update_fail('rampart_locale_ip_address', @rampart.locale_ip_address,
          "Problem saving ip: #{@rampart.errors.full_messages.join(' ')}", ip_id, true)
      end
    rescue Exception => e
      return render_rjs_update_fail('rampart_locale_ip_address', @rampart.locale_ip_address,
        "Problem saving ip: #{e.message}", ip_id, true)
    end
    render_rjs_update_success('rampart_locale_ip_address', @rampart.locale_ip_address,
      'ip saved', ip_id, true)
  end


  def delete
    @rampart = Rampart.find(params[:id])
    @rampart.destroy
    flash[:notice] = "Rampart was DESTROYED."
    redirect_to :action => "list"
  end

  def add_service
    @rampart = Rampart.find(params[:id])
    if (params[:rampart_service_template][:id].to_i == -1) # means user entered custom service
      rampart_service = RampartService.new(params[:rampart_service])
    else
      template = RampartServiceTemplate.find(params[:rampart_service_template][:id])
      rampart_service = RampartService.new(
        :network      => template.network,
        :port         => template.port,
        :protocol     => template.protocol,
        :direction    => template.direction,
        :description  => template.description
      )
    end
    rampart_service.rampart = @rampart
    if rampart_service.save
      flash[:notice] = "Rampart service successfully added."
    else
      flash.now[:error] = "There was an error adding that service: #{rampart_service.errors.full_messages}"
    end

    render :partial => "rampart_service", :locals => { :rampart => @rampart }
  end

  def remove_service
    @rampart = Rampart.new
    @rampart_service = RampartService.find(params[:id])
    @rampart = @rampart_service.rampart
    @rampart_service.destroy

    render :partial => "rampart_service", :locals => { :rampart => @rampart }
  end

private
  def process_ip_input(ip_input, network)
    ip_parts = ip_input.split('/')
    prefix_changed = false
    begin
      IPAddr.new(ip_parts[0])
    rescue ArgumentError
      return [nil, prefix_changed]
    end
    if ip_parts[1].nil? or ip_parts[1] != cidr_mask(network.ip_range)
      ip_final = "#{ip_parts[0]}/#{cidr_mask(network.ip_range)}"
      prefix_changed = true if ip_parts[1]
    else
      ip_final = ip_input
    end
    return [ip_final, prefix_changed]
  end
  def render_rjs_update_success(tag_id, content, message, hidden_content, is_text_field=false)
    render :update do |page|
      page.replace_html "#{tag_id}_success_message", message
      page.replace_html "#{tag_id}_fail_message", ''
      if is_text_field
        page[tag_id].value = content.to_s
        page["#{tag_id}_get"].value = 'Only allowed one address'
        page["#{tag_id}_get"].disabled = true
      else
        page.replace_html tag_id, content.to_s
      end
      page["#{tag_id}_id"].value = hidden_content.to_s
      page.show "#{tag_id}_success_message"
      page.delay(2.5) do
        page.visual_effect :fade, "#{tag_id}_success_message"
      end
    end
  end
  def render_rjs_update_fail(tag_id, content, message, hidden_content, is_text_field=false)
    render :update do |page|
      page.replace_html "#{tag_id}_fail_message", message
      page.replace_html "#{tag_id}_success_message", ''
      page.replace_html tag_id, content.to_s
      page["#{tag_id}_id"].value = hidden_content.to_s
    end
  end
end
