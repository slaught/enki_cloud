class Pushthing < Asynctask
  @queue = "itcfg"
  def self.perform
    puts "RUNNING"
  end

end
