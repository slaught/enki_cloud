#!/bin/sh
#
#

if [ "$UID" -eq "0" ]; then
  echo 'Can NOT run as root'
  exit -1
fi 

P=/enki/bin

case `basename $0` in
downcluster ) ACTION=downnode ;;
upcluster) ACTION=upnode ;;
* ) echo $0: do not call this directly. invalid\! ; exit 9 ;;
esac

if [ "x$1" == "x" ]; then
GROUP=all
else
GROUP=$1
fi

WRAPPER=""

dsh -M -F 50 -g $GROUP $WRAPPER ${P}/${ACTION}
