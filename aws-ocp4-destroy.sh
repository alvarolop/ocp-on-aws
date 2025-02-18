#!/bin/bash

set -euo pipefail

# Script to destroy an OpenShift cluster installed with IPI on AWS.
# Requires two arguments: 
# 1. Path to the file containing variables.
# 2. Directory where the installation files are stored.

# Function to display help
function show_help() {
    echo "Usage: $0 <path-to-vars-file> <workdir>"
    echo
    echo "Arguments:"
    echo "  <path-to-vars-file>  Path to the file containing environment variables (e.g., AWS credentials)."
    echo "  <workdir>            Directory where the installation files (e.g., metadata.json) are stored."
    echo
    echo "Options:"
    echo "  -h, -H, --help       Show this help message and exit."
    echo
    echo "Example:"
    echo "  $0 ./aws-ocp4-config-labs ./workdir-sandbox740-sno"
}

# Check if the user requested help
if [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" || "$1" == "-H" ) ]]; then
    show_help
    exit 0
fi

# Check if the correct number of arguments is provided
if [[ $# -ne 2 ]]; then
    echo "Error: Invalid number of arguments."
    show_help
    exit 1
fi

# Input arguments
VARS_FILE=$1
WORKDIR=$2

# Load variables from the provided file
if [[ -f "$VARS_FILE" ]]; then
    source "$VARS_FILE"
else
    echo "Error: Variables file '$VARS_FILE' does not exist."
    exit 1
fi

# Validate WORKDIR and metadata.json existence
if [[ ! -d "$WORKDIR" ]]; then
    echo "Error: Work directory '$WORKDIR' does not exist."
    exit 1
fi

if [[ ! -f "$WORKDIR/metadata.json" ]]; then
    echo "Error: metadata.json not found in '$WORKDIR'. Ensure this is the correct installation directory."
    exit 1
fi

# Check if AWS environment variables are set, including AWS_REGION
if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" || -z "${AWS_DEFAULT_REGION:-}" ]]; then
    echo "Error: AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_DEFAULT_REGION) are not set."
    exit 1
fi

echo "AWS environment variables are set. Proceeding with cluster destruction..."
echo "Using AWS Region: $AWS_DEFAULT_REGION"

#### OCP CLUSTER DEPROVISIONING ####
echo "Starting cluster destruction..."
$WORKDIR/openshift-install --dir  $WORKDIR destroy cluster  --log-level debug

# Verify if the cluster was destroyed successfully by checking for metadata.json removal or other means.
if [[ -f "$WORKDIR/metadata.json" ]]; then
    echo "Warning: metadata.json still exists. Verify if the cluster was fully destroyed."
else
    echo "Cluster destroyed successfully, metadata.json removed."
fi

echo "Cluster destruction process completed."

# ./aws-ocp4-destroy.sh ./aws-ocp4-config-labs-sno $PWD/workdir-sandbox740-sno
