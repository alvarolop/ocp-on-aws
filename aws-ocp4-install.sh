#!/bin/bash

set -e
# set -x

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
        exit 1
    fi
}

# VARS
source $CONFIG_FILE

OPERATOR_NAMESPACE="openshift-gitops-operator"
ARGOCD_NAMESPACE="gitops"
ARGOCD_CLUSTER_NAME="argocd"

### PREREQUISITES ### 
checkVariable "AWS_ACCESS_KEY_ID"
checkVariable "AWS_SECRET_ACCESS_KEY"
checkVariable "AWS_DEFAULT_REGION"
checkVariable "INSTALL_LETS_ENCRYPT_CERTIFICATES"

#### Print Variables ####
echo
echo ------------------------------------
echo Configuration variables
echo ------------------------------------
echo OPENSHIFT_VERSION=$OPENSHIFT_VERSION
echo RHPDS_GUID=$RHPDS_GUID
echo RHPDS_TOP_LEVEL_ROUTE53_DOMAIN=$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN
echo CLUSTER_NAME=$CLUSTER_NAME
echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
echo AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
echo AWS_AMI=$AWS_AMI
echo RHOCM_PULL_SECRET=$RHOCM_PULL_SECRET
echo RHPDS_SSH_PASSWORD=$RHPDS_SSH_PASSWORD
echo OCP_DOWNLOAD_BASE_URL=$OCP_DOWNLOAD_BASE_URL
echo AWS_BASTION_SG_NAME=$AWS_BASTION_SG_NAME
echo AWS_SUBNET_NAME=$AWS_SUBNET_NAME
echo INSTALL_LETS_ENCRYPT_CERTIFICATES=$INSTALL_LETS_ENCRYPT_CERTIFICATES
echo ------------------------------------


# #### AWS ####

echo "Installation directoy is $CLUSTER_WORKDIR"

mkdir -p $CLUSTER_WORKDIR

# Check if the OS is Linux
if [[ "$os" == "linux"* ]]; then

    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o $CLUSTER_WORKDIR/awscliv2.zip
    unzip -q $CLUSTER_WORKDIR/awscliv2.zip -d $CLUSTER_WORKDIR
    rm -f $CLUSTER_WORKDIR/awscliv2.zip

    $CLUSTER_WORKDIR/aws/install --bin-dir $CLUSTER_WORKDIR/aws/bin --install-dir $CLUSTER_WORKDIR/aws

    $CLUSTER_WORKDIR/aws/bin/aws --version

    ### AWS CONFIG ###

    $CLUSTER_WORKDIR/aws/bin/aws sts get-caller-identity

else
    if ! which aws &> /dev/null; then 
        echo "You need the AWS CLI to run this Quickstart, please, refer to the official documentation:"
        echo -e "\thttps://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi

    aws --version
    aws sts get-caller-identity --region $AWS_DEFAULT_REGION
fi

#### OCP INSTALLER ####

curl -k "${OCP_DOWNLOAD_BASE_URL}/${OPENSHIFT_VERSION}/openshift-install-${os}-${OPENSHIFT_VERSION}.tar.gz" -o $CLUSTER_WORKDIR/openshift-install.tar.gz
tar zxvf $CLUSTER_WORKDIR/openshift-install.tar.gz -C $CLUSTER_WORKDIR
rm -f $CLUSTER_WORKDIR/openshift-install.tar.gz
chmod +x $CLUSTER_WORKDIR/openshift-install

#### OCP CONFIG ####
cat install-config-template.yaml | RHPDS_TOP_LEVEL_ROUTE53_DOMAIN=$(echo $RHPDS_TOP_LEVEL_ROUTE53_DOMAIN) CLUSTER_NAME=$(echo $CLUSTER_NAME) \
  AWS_DEFAULT_REGION=$(echo $AWS_DEFAULT_REGION) RHOCM_PULL_SECRET=$(echo $RHOCM_PULL_SECRET) \
  WORKER_INSTANCE_TYPE=$(echo $WORKER_INSTANCE_TYPE) WORKER_REPLICAS=$(echo $WORKER_REPLICAS) \
  MASTER_INSTANCE_TYPE=$(echo $MASTER_INSTANCE_TYPE) MASTER_REPLICAS=$(echo ${MASTER_REPLICAS:-3}) \
  envsubst >> $CLUSTER_WORKDIR/install-config.yaml

#### OCP INSTALLATION ####

$CLUSTER_WORKDIR/openshift-install --dir  $CLUSTER_WORKDIR create cluster  --log-level debug

#### OC CLI ####

OC_CLI_VERSION=$OPENSHIFT_VERSION

curl -k "${OCP_DOWNLOAD_BASE_URL}/${OC_CLI_VERSION}/openshift-client-${os}-${OC_CLI_VERSION}.tar.gz" -o $CLUSTER_WORKDIR/oc.tar.gz
tar zxvf $CLUSTER_WORKDIR/oc.tar.gz -C $CLUSTER_WORKDIR
rm -f $CLUSTER_WORKDIR/oc.tar.gz
chmod +x $CLUSTER_WORKDIR/oc

#### CREATE USERS ####

KUBEADMIN_PASSWORD=`grep kubeadmin $CLUSTER_WORKDIR/.openshift_install.log | grep password | awk -Fpassword: '{print $2}' | sed 's/\\\""//' | sed 's/\\\"//' | sed 's/\ //'`
echo "kubeadmin password: $KUBEADMIN_PASSWORD"
OCP_API=https://api.$CLUSTER_NAME.$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN:6443
echo "Cluster api url: $OCP_API"
sleep 5
$CLUSTER_WORKDIR/oc login -u kubeadmin -p $KUBEADMIN_PASSWORD $OCP_API --insecure-skip-tls-verify=true
$CLUSTER_WORKDIR/oc create secret generic htpass-secret -n openshift-config --from-file=htpasswd=auth/users.htpasswd
$CLUSTER_WORKDIR/oc apply -f auth/htpasswd_oauth.yaml
echo "Waiting some time to get OAuth configured..."
sleep 30
# Create all the cluster admins
$CLUSTER_WORKDIR/oc apply -f auth/group-cluster-admins.yaml
$CLUSTER_WORKDIR/oc apply -f auth/clusterrolebinding-cluster-admins.yaml

# Do not add redhat as a group, but directly admin (It does not inherit access to gitOps)
$CLUSTER_WORKDIR/oc adm policy add-cluster-role-to-user cluster-admin redhat

echo -n "Waiting for authentication configuration to be ready..."
while ! $CLUSTER_WORKDIR/oc login -u redhat -p 'redhat!1' $OCP_API --insecure-skip-tls-verify=true &> /dev/null; do   echo -n "." && sleep 1; done; echo -n -e " [OK]\n"

if [ $? -eq 0 ]; then
    echo "Deleting kubeadmin password in cluster $OCP_API"
    $CLUSTER_WORKDIR/oc delete secret kubeadmin -n kube-system
else
    echo "WARN: Could not login using redhat user in cluster $OCP_API" 
    echo "Please, check user provisioning manually using kubeadmin user" 
fi

if [[ "$INSTALL_LETS_ENCRYPT_CERTIFICATES" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then

    echo -e "\n==============================="
    echo -e "=     INSTALL CERTIFICATES    ="
    echo -e "===============================\n"
    sleep 10
    source ./aws-ocp4-install-certs.sh $CONFIG_FILE
fi

if [[ "$INSTALL_OPENSHIFT_GITOPS" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then

    echo -e "\n==============================="
    echo -e "=      INSTALL OCP GITOPS     ="
    echo -e "===============================\n"

    # Install OpenShift GitOps operator
    echo -e "\n[1/3]Install OpenShift GitOps operator"

    oc process -f https://raw.githubusercontent.com/alvarolop/ocp-gitops-playground/refs/heads/main/openshift/01-operator.yaml \
        -p OPERATOR_NAMESPACE=$OPERATOR_NAMESPACE | oc apply -f -

    echo -n "Waiting for pods ready..."
    while [[ $(oc get pods -l control-plane=gitops-operator -n $OPERATOR_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

    # Deploy the ArgoCD instance
    echo -e "\n[2/3]Deploy the ArgoCD instance"
    oc process -f https://raw.githubusercontent.com/alvarolop/ocp-gitops-playground/refs/heads/main/openshift/02-argocd.yaml \
        -p ARGOCD_NAMESPACE=$ARGOCD_NAMESPACE \
        -p ARGOCD_CLUSTER_NAME="$ARGOCD_CLUSTER_NAME" | oc apply -f -

    # Wait for DeploymentConfig
    echo -n "Waiting for pods ready..."
    while [[ $(oc get pods -l app.kubernetes.io/name=${ARGOCD_CLUSTER_NAME}-server -n $ARGOCD_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

    ARGOCD_ROUTE=$(oc get routes $ARGOCD_CLUSTER_NAME-server -n $ARGOCD_NAMESPACE --template="https://{{.spec.host}}")

    # Create the ArgoCD ConsoleLink
    echo -e "\n[3/3]Create the ArgoCD ConsoleLink"
    oc process -f https://raw.githubusercontent.com/alvarolop/ocp-gitops-playground/refs/heads/main/openshift/03-consolelink.yaml \
        -p ARGOCD_ROUTE=$ARGOCD_ROUTE \
        -p ARGOCD_NAMESPACE=$ARGOCD_NAMESPACE \
        -p ARGOCD_CLUSTER_NAME="$ARGOCD_CLUSTER_NAME" | oc apply -f -
fi

# Print values to access the cluster

OCP_API=https://api.$CLUSTER_NAME.$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN:6443
OCP_CONSOLE=https://console-openshift-console.apps.$CLUSTER_NAME.$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN

echo ""
echo "Installation finished!!!"
echo ""
echo "You can access the cluster using the console or the CLI"
echo -e "\t* Web: $OCP_CONSOLE"
echo -e "\t* CLI: oc login -u redhat $OCP_API # You can use any other user"
echo ""
