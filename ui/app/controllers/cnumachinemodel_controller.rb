
class CnumachinemodelController < ApplicationController

  def index
    render :nothing => true, :status => 200
  end
  def list
    render :nothing => true, :status => 200
  end
  def show
    @cnumachinemodel = CnuMachineModel.find(params[:id])
    render 
  end
end
