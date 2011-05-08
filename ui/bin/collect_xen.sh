#!/bin/bash

PASS=test
USER=cnusnmpuser 
echo "`echo $1 |cut -d. -f1,2 -s`:"
/usr/bin/snmpget $1 -r 10 -t 7 -Ov -v3 -l authPriv -a MD5 -u $USER -A $PASS -x DES -X $PASS .1.3.6.1.4.1.30838.1.3.5.1.1.3.3.1.1.0 2>/dev/null |grep "STRING" |sed 's!STRING: !!' |grep -v ":" |tr -d '"' |tr -d '\n' |tr -t ' ' '\n' |awk '{print " - \""$1"\""}'
