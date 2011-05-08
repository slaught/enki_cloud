#!/bin/bash

MASTER_NODE_PREFIX="xen01."
XEN_CLUSTER_STATUS_BIN="/etc/cnu/scripts/xen-cluster-map"
usage="USAGE: $0 -d DATACENTER"

while getopts ":d:" flag
do
  case $flag in
    d)
      datacenter=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

if [ -z "$datacenter" ]; then
 echo $usage
 exit 1
fi

ssh -A $MASTER_NODE_PREFIX$datacenter $XEN_CLUSTER_STATUS_BIN
  
 
