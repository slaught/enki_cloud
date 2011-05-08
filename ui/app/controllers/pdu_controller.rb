class PduController < ApplicationController
  include AuthenticatedSystem

  def index
    redirect_to :action => "list"
  end

  def show
    @pdu = Node.find(params[:id])
    unless @pdu.node_type.node_type == "pdu"
      flash.now[:error] = "Oops, the supplied node is not a PDU"
    end
    @plugs = Pdu.find_all_by_pdu_id(@pdu.id)
  end

  def list
    @pdus = Node.find_all_pdus
  end

end
