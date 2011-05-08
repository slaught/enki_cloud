#!/bin/bash

# This script restarts services if their config files have changed
# within the $TIMEOUT period
# It should be used as a post_cmd in a warsync filepack that updates /etc,
# probably /etc/warsync/filepacks/10-etc
# The line to be added to the filepack is:
# post_cmd = /etc/enki/scripts/warsync-post-etc.sh

# Services are defined using exactly two fields separated by a colon:
# /path/to/config/file:/path/to/script
# If warsync updates a config file, the corresponding script is executed with
# `restart' parameter.
# Feel free to add more services

# Author: Andy Tsouladze
# Date: 20100819

DATE=/bin/date
SED=/bin/sed
STAT=/usr/bin/stat
TIMEOUT=10

NOW=`$DATE +%s`

SERVICES="
/etc/syslog-ng/syslog-ng.conf:/etc/init.d/syslog-ng
/etc/postfix/main.cf:/etc/init.d/postfix
"

for service in $SERVICES ; do
        CONF=`echo $service | $SED s/:.*//`
        SCRIPT=`echo $service | $SED s/.*://`
        if [ -e $CONF ] && [ -e $SCRIPT ] ; then
                MOD=`$STAT -Lc %Z $CONF`
                if [ $(($NOW - $MOD)) -lt $TIMEOUT ] ; then
                        echo "Running \"$SCRIPT restart\""
        #               $SCRIPT restart
                fi
        fi
done

