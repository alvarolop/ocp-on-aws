#!/bin/bash

# VARS
CLUSTER_WORKDIR=$1

# Check that the aws cli is installed if you want to interact with AWS.
if ! command -v aws &>/dev/null ; then
    echo "❌ aws cli is not installed."
    echo "💡 Exiting. Please, install aws cli."
    exit 1
fi

CLUSTERID=`cat $CLUSTER_WORKDIR/metadata.json | awk -F\"infraID\":\" '{print $2}' | awk -F\", '{print $1}'` 
REGION=`cat $CLUSTER_WORKDIR/metadata.json | awk -F\"region\":\" '{print $2}' | awk -F\", '{print $1}'` 

echo "CLUSTERID=$CLUSTERID; REGION=$REGION"

INSTANCE_IDS=$(
    aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=tag:kubernetes.io/cluster/${CLUSTERID},Values=owned" \
        --query "Reservations[].Instances[].[InstanceId]" \
        --output text | tr '\n' ' '
)

aws ec2 start-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS
