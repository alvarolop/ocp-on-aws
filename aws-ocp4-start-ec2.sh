#!/bin/bash

# VARS
CLUSTER_WORKDIR=$1

CLUSTERID=`cat $CLUSTER_WORKDIR/metadata.json | awk -F\"infraID\":\" '{print $2}' | awk -F\", '{print $1}'` 
REGION=`cat $CLUSTER_WORKDIR/metadata.json | awk -F\"region\":\" '{print $2}' | awk -F\", '{print $1}'` 

echo "CLUSTERID=$CLUSTERID; REGION=$REGION"

$CLUSTER_WORKDIR/aws/bin/aws ec2 start-instances --instance-ids $($CLUSTER_WORKDIR/aws/bin/aws ec2 describe-instances --filters  "Name=tag:kubernetes.io/cluster/${CLUSTERID},Values=owned" --query "Reservations[].Instances[].[InstanceId]" --output text | tr '\n' ' ')

