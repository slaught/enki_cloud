# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include AuthenticatedSystem  
  # Pick a unique cookie name to distinguish our session data from others'
  #session :key => '_cnu_it_session'
  helper :all

  # rescue_from PG ActiveRecord::RecordNotFound, :with => :record_not_found private def record_not_found render :text => "404 Not Found", :status => 404 end 

  rescue_from ActionView::TemplateError do |exp|
    flash[:error] = exp.to_s 
    begin
      render :text => exp.to_s 
      # redirect_to :back 
    rescue
      render :text =>exp.to_s,  :status => 500
    end
  end

  before_filter :set_current_user

  def permission_denied
    flash[:error] = I18n.t :permission_denied 
    redirect_to :back rescue redirect_to "/"
  end

  protected
  def set_current_user
    Authorization.current_user = current_user
  end

# ActionView::TemplateError (PGError: ERROR:  column pdus.node_id does not exist
# LINE 1: SELECT * FROM "pdus"     WHERE ("pdus".node_id = 458) 
#                                         ^
# : SELECT * FROM "pdus"     WHERE ("pdus".node_id = 458) ) on line #9 of node/_pdus.html.erb:
# 6: <h3>PDUs</h3>
# 7: <table class="pdu">
# 8: <tr><td>PDU</td><td>Outlet</td></tr>
# 9: <% for p in node.pdus %>
# 10: <tr><td><%= p.pdu.fn_prefix %></td><td><%= p.outlet_no %></td>
# 11:   <% permitted_to? :unplug_pdu, :node do %>
# 12:   <td>

      #   class ApplicationController < ActionController::Base
      #     rescue_from User::NotAuthorized, :with => :deny_access # self defined exception
      #     rescue_from ActiveRecord::RecordInvalid, :with => :show_errors
      #
      #     rescue_from 'MyAppError::Base' do |exception|
      #       render :xml => exception, :status => 500
      #     end
      #
      #     protected
      #       def deny_access
      #         ...
      #       end
      #
      #       def show_errors(exception)
      #         exception.record.new_record? ? ...
      #       end
      #   end




end
