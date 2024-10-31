#!/bin/bash

set -e

# VARS
source $1

# VARS
WORKDIR=$2

### PREREQUISITES ### 

# TODO Check existance
#export AWS_ACCESS_KEY_ID=<x>
#export AWS_SECRET_ACCESS_KEY=<y>
#export AWS_DEFAULT_REGION=<region>

# TODO validate value of WORKDIR and metadata.json in it

#### OCP CLUSTER DEPROVISIONING ####

$WORKDIR/openshift-install --dir  $WORKDIR destroy cluster  --log-level debug

# ./aws-ocp4-destroy.sh ./aws-ocp4-config-labs $PWD/ocp4-sandbox63