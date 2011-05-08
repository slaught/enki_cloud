#30 8 1 * * cnuit  /export/web/cnu_it/bin/cron-task ClearOldSessions
class ClearOldSessions < Asynctask
  @queue = "itcfg"
  def self.perform
    self.delete_month_old_sessions
  end
  def self.delete_month_old_sessions
    c = "updated_at <  now() - interval '1 month'"
    self.delete_old_sessions(c)
  end
  def self.delete_old_sessions(condition)
    count = ActiveRecord::SessionStore::Session.count(:conditions =>[condition]) 
    deleted = ActiveRecord::SessionStore::Session.delete_all(condition)
    return (count == deleted) 
  end

end
