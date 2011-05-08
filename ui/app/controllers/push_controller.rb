class PushController < ApplicationController
  filter_access_to :all

  def index
    redirect_to :list
  end
  def list
  end

  def scs
    res = Resque.enqueue(Pushscs)
    render :layout => false, :text => "<strong>SCS has been queued for push!</strong>"
  end

  def pdu
    res = Resque.enqueue(Pushpdu)
    render :layout => false, :text => "<strong>PDU has been queued for push!</strong>"
  end
  
  def host
  end

  def host_push
    which_host = params[:hosts]
    host = params[:host]
    if which_host == "all"
      res = Resque.enqueue(Pushclient)
    elsif which_host == "one" and host != ""
      res = Resque.enqueue(Pushclient, host)
    end
  end
end
