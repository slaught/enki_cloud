# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include CNU::Conversion

 def editable_content(options)
   options[:content] = { :element => 'span' }.merge(options[:content])
   options[:url] = {}.merge(options[:url])
   options[:ajax] = { :okText => "Save", :cancelText => "Cancel"}.merge(options[:ajax] || {})
   ajax_options = options[:ajax].map do |key, value| 
                  if [:okText, :cancelText].member? key then
                    "#{key.to_s}: '#{value}'" 
                  else
                    "#{key.to_s}: #{value}" 
                  end
   end
   script = %Q(
              new Ajax.InPlaceEditor(
                '#{options[:content][:options][:id]}',
                '#{url_for(options[:url])}',
                { #{ajax_options.join(",")} }
              )
  )
   content_tag(
     options[:content][:element],
     options[:content][:text],
     options[:content][:options]
   ) + javascript_tag( script )
 end
 def editable_content_inline(entity, attribute, options)
   controller_name = entity.class.to_s.downcase 
   attribute_name  = attribute.to_s
   html_id  =  "#{controller_name}_#{attribute_name}_edit_#{entity.id}"
   options[:content] = { :element => 'span', :text => entity.send(attribute) 
              }.merge(options[:content])
   options[:content][:options] = { :id => html_id }.merge(options[:content][:options])
   options[:url] = {:controller => controller_name, :id => entity.id,
                    :action => 'update', :attribute => attribute_name }.merge(options[:url])
   options[:ajax] = { :okText => "Save", :cancelText => "Cancel"}.merge(options[:ajax] || {})
   ajax_options = options[:ajax].map do |key, value| 
                  if [:okText, :cancelText].member? key then
                    "#{key.to_s}: '#{value}'" 
                  else
                    "#{key.to_s}: #{value}" 
                  end
   end
   script = %Q(
              new Ajax.InPlaceEditor(
                '#{html_id}',
                '#{url_for(options[:url])}',
                { #{ajax_options.join(",")} }
              )
  )
   content_tag(
     options[:content][:element],
     options[:content][:text],
     options[:content][:options]
   ) + javascript_tag( script )
 end

  def lb_fullurl(obj)
    return "BROKEN" if obj.nil?
    url_for( :action => "show", :controller=>obj.class, :id=> obj, \
           :host=>'somewhere.example.com', :protocol => 'http')
  end
  def lb_link(obj, link_label=nil)
    link_label = obj.to_label if link_label.nil?
    link_to link_label, lb_fullurl(obj)
  end
  def link_to_cluster(cluster)
    return "BROKEN" if cluster.nil?
    link_to cluster.to_label, :action => "show", :controller=>"cluster", :id=> cluster
  end
  def link_to_node(node)
    return "BROKEN" if node.nil?
    link_to node.to_label, :action => "show", :controller=>"node", :id=> node 
  end
  def link_to_pdu(pdu)
    return "BROKEN" if pdu.nil?
    link_to pdu.to_label, :action => "show", :controller => "pdu", :id => pdu
  end
  def link_to_machine(model)
    if model.nil? then
      ''
    else
      link_to model.to_label, :controller => "machine", :action => "show", :id => model
    end
  end
  def toc_link_loc(label,q)
    _toc_link(label, 'loc',q)
  end
  def toc_link_cls(label,q)
    _toc_link(label, 'cls',q)
  end
  def _toc_link(label, action, q)
    link_to label, :controller => 'node', :action => action, :id => q
  end
  def nagios_link(node, link_label)
    dc = node.datacenter.name
    name = node.to_label
    link_to link_label, "https://nagios.#{dc}.example.com/cgi-bin/nagios3/extinfo.cgi?type=1&host=#{name}"
  end
  def  layout_edit_element(label, editfield)
    %Q(<fieldset><legend>#{label}</legend>#{editfield}</fieldset>)
  end
  def layout_show_element(label, value)
    v = case value
      when NilClass
        nil
      when Numeric
        value
      when String
        if value.length > 0 
          value 
        end
      else
        value.to_s
    end
    if v then 
      %Q(<p><b>#{label}</b>\n #{h v}</p>)
    else
      ''
    end
  end
  def set_html_title(*args)
    unless args.blank?
      content_for :html_title do
        "#{args.join(" &ndash; ")} &ndash; "
      end
    end
  end
  def edit_link_to(action)
      link_to( image_tag("/images/silk/page_white_edit.png", :alt => "Edit"), action, {:title => "Edit"} )
  end
  def destroy_link_to(action)
    link_to( image_tag("/images/silk/cross.png", :alt => "Destroy"), action, 
        {:confirm => "Are you sure?", :method => :post, :title => "Destroy" })
  end
  def sorttable_ip(i)
    ip2dec(ip(i)) if i
  end
end
