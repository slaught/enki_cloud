class EthernetController < ApplicationController

  def list
    @ports = NetworkSwitchPort.find(:all, :order => 'port')
    render 
  end

end
