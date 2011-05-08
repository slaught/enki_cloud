class Pushscs < Asynctask
  @queue = "itcfg"
  def self.perform
    `/usr/bin/push-itcfg -s 2>&1 | tee -a /var/log/async-pushscs`    
  end
end
