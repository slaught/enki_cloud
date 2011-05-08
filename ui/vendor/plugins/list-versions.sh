#!/bin/sh
GIT="git --git-dir"
DIRS=`ls -d */.git |sort `
for i in $DIRS
do 
if [ -d ${i} ] ; then
  echo plugin `echo ${i} | cut -d / -f 1`
  echo -ne  "origin\t"
  ${GIT}=${i} config --get remote.origin.url 
  ${GIT}=${i} log -1 --pretty=medium |cat 
fi
done


