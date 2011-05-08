#!/bin/sh
if (set -u; : $SUDO_USER) 2> /dev/null
then
  echo "NO! NO! NO! DO NOT CALL THIS WITH SUDO. IT DOES IT FOR YOU."
else
  cd /export/web/base_config_layout
  sudo -u cnuit /export/web/cnu_it/bin/gen_layout.rb $@ 
fi


