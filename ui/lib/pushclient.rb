class Pushclient < Asynctask
  @queue = "itcfg"
  def self.perform(client = "all")
    if client == "all"
      `/usr/bin/push-itcfg -a 2>&1 | tee -a /var/log/async-pushclient`
    else
      `/usr/bin/push-itcfg -c #{client} 2>&1 | tee -a /var/log/async-pushclient`
    end
  end
end
