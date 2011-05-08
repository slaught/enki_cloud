class Pushpdu < Asynctask
  @queue = "itcfg"
  def self.perform
    `/usr/bin/push-itcfg -p 2>&1 | tee -a /var/log/async-pushpdu`    
  end
end
