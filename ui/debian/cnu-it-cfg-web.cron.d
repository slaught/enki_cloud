# Regular cron jobs for the cnu-it-web package
#

# push out serial console configs
45 22 * * * cnuit  /export/web/cnu_it/bin/cron-task Pushscs

# 
# 8:30am first day of the month: Clear old sessions 
30 8 1 * * cnuit  /export/web/cnu_it/bin/cron-task ClearOldSessions
