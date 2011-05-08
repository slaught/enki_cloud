#!/bin/sh
#
#
#
# Check if we are running as root.
if [ "$UID" -ne "0" ]; then
  exec sudo $0 $@
fi

case `basename $0` in
downnode ) ACTION=down ;;
upnode ) ACTION=up ;;
* ) echo $0: can not call this directly. invalid\! ; exit 9 ;;
esac

FILE=/down
case $ACTION  in
 down ) 
    if [ ! -e $FILE ] ; then 
      echo auto down by $SUDO_USER at `date` > $FILE
    fi;;
 up ) 
    if [ -e $FILE ] ; then
      rm $FILE
    fi  ;;
 * )
    echo "Invalid action: $ACTION";;
esac




