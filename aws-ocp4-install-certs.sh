#!/bin/bash

set -e

CONFIG_FILE=$1

## Check if mac or linux
UNAMEOUT=$(uname -s)

case "${UNAMEOUT}" in
    Linux*)     os=linux;;
    Darwin*)    os=mac;;
esac

function checkVariable {
    if [[ -z ${!1} ]]; then
        echo "Must provide $1 in environment!" 1>&2
        sleep 30
        # exit 1
    fi
}

# VARS
source $CONFIG_FILE

### PREREQUISITES ### 
checkVariable "AWS_ACCESS_KEY_ID"
checkVariable "AWS_SECRET_ACCESS_KEY"
checkVariable "AWS_DEFAULT_REGION"
checkVariable "INSTALL_LETS_ENCRYPT_CERTIFICATES"

echo "Installation directoy is $CLUSTER_WORKDIR"

#### ADD Let's Encrypt Certificates ####
echo "Applying Let's Encrypt certificates..."


podman pull docker.io/neilpang/acme.sh:latest

# This code is based on the following Blog:
# https://cloud.redhat.com/blog/requesting-and-installing-lets-encrypt-certificates-for-openshift-4

# Let's encrypt variables
LE_API=$($CLUSTER_WORKDIR/oc whoami --show-server | cut -f 2 -d ':' | cut -f 3 -d '/' | sed 's/-api././')
LE_WILDCARD=$($CLUSTER_WORKDIR/oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')

CERTDIR=$CLUSTER_WORKDIR/certificates
mkdir -p $CERTDIR

echo -e "\n# STEP 1:\n# Certificate Issuance: The first acme.sh --issue command requests the certificate from the ACME server and generates the necessary .cer and .key files.\n"
podman run --rm -it  \
  -v "${CERTDIR}":/acme.sh:z  \
  --net=host -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  docker.io/neilpang/acme.sh:latest --issue -d $LE_API -d *.$LE_WILDCARD --dns dns_aws --server letsencrypt

# Output should look like this
# /home/alopezme/apps/ocp-on-aws/ocp4-sandbox1464/certificates
# ├── account.conf
# ├── api.ocp.sandbox1464.opentlc.com_ecc
# │   ├── api.ocp.sandbox1464.opentlc.com.cer
# │   ├── api.ocp.sandbox1464.opentlc.com.conf
# │   ├── api.ocp.sandbox1464.opentlc.com.csr
# │   ├── api.ocp.sandbox1464.opentlc.com.csr.conf
# │   ├── api.ocp.sandbox1464.opentlc.com.key
# │   ├── ca.cer
# │   └── fullchain.cer
# ├── ca
# │   └── acme-v02.api.letsencrypt.org
# │       └── directory
# │           ├── account.json
# │           ├── account.key
# │           └── ca.conf
# └── http.header

echo -e "\n# STEP 2:\n# Certificate Conversion: The acme.sh --install-cert command converts these files into the .pem format needed by OpenShift. It uses the appropriate --cert-file, --key-file, and --fullchain-file options to specify where to place the converted files.\n"

podman run --rm -it  \
  -v "${CERTDIR}":/acme.sh:z --net=host \
  docker.io/neilpang/acme.sh:latest --install-cert -d $LE_API -d *.$LE_WILDCARD \
    --cert-file /acme.sh/cert.pem --key-file /acme.sh/privkey.pem --fullchain-file /acme.sh/fullchain.pem --ca-file /acme.sh/ca.cer

# Output should look like this
# /home/alopezme/apps/ocp-on-aws/ocp4-sandbox1464/certificates
# ├── account.conf
# ├── api.ocp.sandbox1464.opentlc.com_ecc
# │   ├── api.ocp.sandbox1464.opentlc.com.cer
# │   ├── api.ocp.sandbox1464.opentlc.com.conf
# │   ├── api.ocp.sandbox1464.opentlc.com.csr
# │   ├── api.ocp.sandbox1464.opentlc.com.csr.conf
# │   ├── api.ocp.sandbox1464.opentlc.com.key
# │   ├── backup
# │   ├── ca.cer
# │   └── fullchain.cer
# ├── ca
# │   └── acme-v02.api.letsencrypt.org
# │       └── directory
# │           ├── account.json
# │           ├── account.key
# │           └── ca.conf
# ├── ca.cer
# ├── cert.pem
# ├── fullchain.pem
# ├── http.header
# └── privkey.pem

# Upload certificates to OCP
## Installing Certificates for Ingress Controllers
$CLUSTER_WORKDIR/oc create secret tls ingress-certs --cert=${CERTDIR}/fullchain.pem --key=${CERTDIR}/privkey.pem -n openshift-ingress
## Installing Certificates for the API
$CLUSTER_WORKDIR/oc create secret tls api-certs --cert=${CERTDIR}/fullchain.pem --key=${CERTDIR}/privkey.pem -n openshift-config

# Configure services to take the new certificates
## Ingress controllers
$CLUSTER_WORKDIR/oc patch ingresscontroller default -n openshift-ingress-operator --type=merge --patch='{"spec": { "defaultCertificate": { "name": "ingress-certs" }}}'
## OCP API
$CLUSTER_WORKDIR/oc patch apiserver cluster --type=merge --patch='{"spec": {"servingCerts": {"namedCertificates": [{"names": [" '$LE_API' "], "servingCertificate": {"name": "api-certs"}}]}}}'


# Check cluster operators status
set +e  # Disable exit on non-zero status to keep the script running even if commands fail. THere is no HA when cluster is SNO
echo -e "\nCheck cluster operators..."
while true; do
    $CLUSTER_WORKDIR/oc get clusteroperators
    STATUS_AUTHENTICATION=$($CLUSTER_WORKDIR/oc get clusteroperators authentication -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
    STATUS_CONSOLE=$($CLUSTER_WORKDIR/oc get clusteroperators console -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
    STATUS_KUBE_API_SERVER=$($CLUSTER_WORKDIR/oc get clusteroperators kube-apiserver -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
    STATUS_KUBE_SCHEDULER=$($CLUSTER_WORKDIR/oc get clusteroperators kube-scheduler -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
    STATUS_KUBE_CONTROLLER_MANAGER=$($CLUSTER_WORKDIR/oc get clusteroperators kube-controller-manager -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')

    # echo "STATUS_AUTHENTICATION $STATUS_AUTHENTICATION"
    # echo "STATUS_CONSOLE $STATUS_CONSOLE"
    # echo "STATUS_KUBE_API_SERVER $STATUS_KUBE_API_SERVER"
    # echo "STATUS_KUBE_SCHEDULER $STATUS_KUBE_SCHEDULER"
    # echo "STATUS_KUBE_CONTROLLER_MANAGER $STATUS_KUBE_CONTROLLER_MANAGER"

    if [ $STATUS_AUTHENTICATION == "False" ] && [ $STATUS_CONSOLE == "False" ] && [ $STATUS_KUBE_API_SERVER == "False" ] && [ $STATUS_KUBE_SCHEDULER == "False" ] && [ $STATUS_KUBE_CONTROLLER_MANAGER == "False" ]; then
        echo -e "\n\tOperators updated!!\n"
        break
    fi

    echo -e "Cluster operators are still progressing...Sleep 60s...\n"
    sleep 60
done

set -e  # Re-enable exit on non-zero status after the loop
