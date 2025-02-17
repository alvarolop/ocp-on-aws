#!/bin/bash

# exec examples
# ./aws-ocp4-install.sh aws-ocp4-config
# GROUP_FILE_PATH=auth/other-group-cluster-admins.yaml HTPASSWD_PATH=auth/other-users.htpasswd ./aws-ocp4-install.sh aws-ocp4-config

set -e
# set -x

CONFIG_FILE=$1

## Check if mac or linux
case "$(uname -s)" in
    Linux*)  os=linux;;
    Darwin*) os=mac;;
    *)       os=unknown;;
esac

# VARS
source $CONFIG_FILE

# Extra configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_WORKDIR="${BASE_DIR}/ocp4-sandbox${RHPDS_GUID}"

OPERATOR_NAMESPACE="openshift-gitops-operator"
ARGOCD_NAMESPACE="openshift-gitops"
ARGOCD_CLUSTER_NAME="argocd"

K_DEFAULT_USER="redhat"
K_DEFAULT_PASSWD="${K_DEFAULT_PASSWD:-redhat!1}"

# functs
OC_PATH="$CLUSTER_WORKDIR/oc"
function oc() {
   $OC_PATH "$@"
}

function checkVariable {
    if [[ -z ${!1} ]]; then
        echo "Must provide $1 in environment!" 1>&2
        exit 1
    fi
}

# Random suffix generator
function generate_random_password {
    tr -dc 'a-z0-9' </dev/urandom | head -c 15
}

function show_tmp_credentials {
    rm $HTPASSWD_PATH
    echo "The password is $K_DEFAULT_PASSWD and is stored in this temp htpasswd file $HTPASSWD_PATH"
}

# echo -e "\n================="
# echo -e "=   PRE-CHECKS  ="
# echo -e "=================\n"


# ### PREREQUISITES ### 
# checkVariable "AWS_ACCESS_KEY_ID"
# checkVariable "AWS_SECRET_ACCESS_KEY"
# checkVariable "AWS_DEFAULT_REGION"
# checkVariable "INSTALL_LETS_ENCRYPT_CERTIFICATES"
# checkVariable "INSTALL_OPENSHIFT_GITOPS"


# # Check if the users file exists. If not, generate a temporary one and share the password at the end.
# if [ -f ${HTPASSWD_PATH:-auth/users.htpasswd} ]; then

#     echo -e "\nThe users htpasswd file exists."

# else 
#     echo -e "\nThe users file does not exist, we will generate a user/password file."
#     K_DEFAULT_PASSWD=$(generate_random_password)
#     HTPASSWD_PATH=$(mktemp -t users.htpasswd.XXXXXXXXXX)
#     GROUP_FILE_PATH=${GROUP_FILE_PATH:-auth/group-cluster-admins.yaml.example}
#     htpasswd -b -B $HTPASSWD_PATH redhat $K_DEFAULT_PASSWD
#     echo "The password is $K_DEFAULT_PASSWD and is stored in this temp htpasswd file $HTPASSWD_PATH, which contents are: "
#     cat $HTPASSWD_PATH
#     trap show_tmp_credentials EXIT
# fi 

# # Check if the user / password is correct, so that auth section works fine.
# if command -v htpasswd &> /dev/null; then
#     if ! htpasswd -vb "${HTPASSWD_PATH:-auth/users.htpasswd}" $K_DEFAULT_USER $K_DEFAULT_PASSWD; then
#         echo "Password verification failed for user $K_DEFAULT_USER or user does not exist"
#         echo "Check line 27 and "
#         exit 1
#     fi
# else
#     echo "htpasswd command not found"
#     echo "You should install it if you want this verification."
#     echo "In Fedora: sudo dnf install httpd-tools"
# fi

# # Check that the podman cli is installed if you want the certificates.
# if ! command -v podman &>/dev/null && [[ ${INSTALL_LETS_ENCRYPT_CERTIFICATES} =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then
#     echo "Podman is not installed, and INSTALL_LETS_ENCRYPT_CERTIFICATES is set to True/Yes/1."
#     echo "Exiting. Please, install podman."
# fi

# #### Print Variables ####
# echo
# echo ------------------------------------
# echo Configuration variables
# echo ------------------------------------
# echo OPENSHIFT_VERSION=$OPENSHIFT_VERSION
# echo RHPDS_GUID=$RHPDS_GUID
# echo RHPDS_TOP_LEVEL_ROUTE53_DOMAIN=$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN
# echo CLUSTER_NAME=$CLUSTER_NAME
# echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
# echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
# echo AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
# echo INSTALL_LETS_ENCRYPT_CERTIFICATES=$INSTALL_LETS_ENCRYPT_CERTIFICATES
# echo INSTALL_OPENSHIFT_GITOPS=$INSTALL_OPENSHIFT_GITOPS
# echo ------------------------------------


# echo -e "\n============================="
# echo -e "=   OPENSHIFT INSTALLATION  ="
# echo -e "=============================\n"


# # #### AWS ####

# echo "Installation directoy is $CLUSTER_WORKDIR"

# mkdir -p $CLUSTER_WORKDIR
# echo "$K_DEFAULT_PASSWD" >> $CLUSTER_WORKDIR/default-user-password

# #### OCP INSTALLER ####

# curl -k "${OCP_DOWNLOAD_BASE_URL}/${OPENSHIFT_VERSION}/openshift-install-${os}-${OPENSHIFT_VERSION}.tar.gz" -o $CLUSTER_WORKDIR/openshift-install.tar.gz
# tar zxvf $CLUSTER_WORKDIR/openshift-install.tar.gz -C $CLUSTER_WORKDIR
# rm -f $CLUSTER_WORKDIR/openshift-install.tar.gz
# chmod +x $CLUSTER_WORKDIR/openshift-install

# #### OC CLI ####

# curl -k "${OCP_DOWNLOAD_BASE_URL}/${OPENSHIFT_VERSION}/openshift-client-${os}-${OPENSHIFT_VERSION}.tar.gz" -o $CLUSTER_WORKDIR/oc.tar.gz
# tar zxvf $CLUSTER_WORKDIR/oc.tar.gz -C $CLUSTER_WORKDIR
# rm -f $CLUSTER_WORKDIR/oc.tar.gz
# chmod +x $CLUSTER_WORKDIR/oc

# #### OCP CONFIG ####
# cat install-config-template.yaml | RHPDS_TOP_LEVEL_ROUTE53_DOMAIN=$(echo $RHPDS_TOP_LEVEL_ROUTE53_DOMAIN) CLUSTER_NAME=$(echo $CLUSTER_NAME) \
#   AWS_DEFAULT_REGION=$(echo $AWS_DEFAULT_REGION) RHOCM_PULL_SECRET=$(echo $RHOCM_PULL_SECRET) \
#   WORKER_INSTANCE_TYPE=$(echo $WORKER_INSTANCE_TYPE) WORKER_REPLICAS=$(echo $WORKER_REPLICAS) \
#   MASTER_INSTANCE_TYPE=$(echo $MASTER_INSTANCE_TYPE) MASTER_REPLICAS=$(echo ${MASTER_REPLICAS:-3}) \
#   SSH_PUBLIC_KEY=$(echo $SSH_PUBLIC_KEY) \
#   envsubst >> $CLUSTER_WORKDIR/install-config.yaml

# echo -e "\nThis is the value of the install-config YAML:"
# cat $CLUSTER_WORKDIR/install-config.yaml 

# #### OCP INSTALLATION ####

# $CLUSTER_WORKDIR/openshift-install --dir $CLUSTER_WORKDIR create cluster --log-level debug

# sleep 5


# #### CREATE USERS ####

# echo -e "\n==============================="
# echo -e "=   Configure authentication  ="
# echo -e "===============================\n"

# KUBEADMIN_PASSWORD=$(cat "$CLUSTER_WORKDIR/auth/kubeadmin-password")
# OCP_API=https://api.$CLUSTER_NAME.$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN:6443

# echo -e "\t- kubeadmin password: $KUBEADMIN_PASSWORD"
# echo -e "\t- Cluster api url: $OCP_API"
# echo ""

# oc login -u kubeadmin -p $KUBEADMIN_PASSWORD $OCP_API --insecure-skip-tls-verify=true

# oc create secret generic htpass-secret -n openshift-config --from-file=htpasswd="${HTPASSWD_PATH:-auth/users.htpasswd}"
# oc apply -f auth/oauth-cluster.yaml
# oc apply -f "${GROUP_FILE_PATH:-auth/group-cluster-admins.yaml}"
# oc apply -f auth/clusterrolebinding-cluster-admins.yaml

# # Do not add default user as a group, but directly admin (It does not inherit access to gitOps)
# oc adm policy add-cluster-role-to-user cluster-admin ${K_DEFAULT_USER}

# echo "Waiting some time to get OAuth configured..."
# sleep 40

# # auth
# echo -en "\nWaiting for authentication configuration to be ready..."

# MAX_ATTEMPTS=${MAX_ATTEMPTS:-50}
# ATTEMPT=0
# K_LOGIN_SUCCESS=-1

# while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
#     if oc login -u ${K_DEFAULT_USER} -p ${K_DEFAULT_PASSWD} $OCP_API --insecure-skip-tls-verify=true &> /dev/null; then
#         K_LOGIN_SUCCESS=0
#         break
#     fi
#     echo -n "."
#     ATTEMPT=$((ATTEMPT + 1))
#     sleep 5
# done

# if [ $K_LOGIN_SUCCESS -eq 0 ]; then
#     echo -e " [OK]"
#     echo "Deleting kubeadmin password in cluster $OCP_API"
#     oc delete secret kubeadmin -n kube-system
# else
#     echo -e "\nERROR: Could not login using ${K_DEFAULT_USER} user in cluster $OCP_API after $MAX_ATTEMPTS attempts."
#     echo "Please, check user provisioning manually using kubeadmin user."
#     K_DEFAULT_USER="kubeadmin"
# fi

# if [[ "$INSTALL_OPENSHIFT_GITOPS" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then

#     echo -e "\n==============================="
#     echo -e "=      INSTALL OCP GITOPS     ="
#     echo -e "===============================\n"

#     # Install OpenShift GitOps operator
#     echo -e "\n[1/3]Install OpenShift GitOps operator"

#     oc process -f https://raw.githubusercontent.com/alvarolop/ocp-gitops-playground/refs/heads/main/openshift/01-operator.yaml \
#         -p OPERATOR_NAMESPACE=$OPERATOR_NAMESPACE | oc apply -f -

#     echo -n "Waiting for pods ready..."
#     while [[ $(oc get pods -l control-plane=gitops-operator -n $OPERATOR_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

#     # Deploy the ArgoCD instance
#     echo -e "\n[2/3]Deploy the ArgoCD instance"
#     oc process -f https://raw.githubusercontent.com/alvarolop/ocp-gitops-playground/refs/heads/main/openshift/02-argocd.yaml \
#         -p ARGOCD_NAMESPACE=$ARGOCD_NAMESPACE \
#         -p ARGOCD_CLUSTER_NAME="$ARGOCD_CLUSTER_NAME" | oc apply -f -

#     # Wait for DeploymentConfig
#     echo -n "Waiting for pods ready..."
#     while [[ $(oc get pods -l app.kubernetes.io/name=${ARGOCD_CLUSTER_NAME}-server -n $ARGOCD_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

#     ARGOCD_ROUTE=$(oc get routes $ARGOCD_CLUSTER_NAME-server -n $ARGOCD_NAMESPACE --template="https://{{.spec.host}}")

#     # Create the ArgoCD ConsoleLink
#     echo -e "\n[3/3]Create the ArgoCD ConsoleLink"
#     oc process -f https://raw.githubusercontent.com/alvarolop/ocp-gitops-playground/refs/heads/main/openshift/03-consolelink.yaml \
#         -p ARGOCD_ROUTE=$ARGOCD_ROUTE \
#         -p ARGOCD_NAMESPACE=$ARGOCD_NAMESPACE \
#         -p ARGOCD_CLUSTER_NAME="$ARGOCD_CLUSTER_NAME" | oc apply -f -
# fi

# if [[ "$INSTALL_LETS_ENCRYPT_CERTIFICATES" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then

#     echo -e "\n==============================="
#     echo -e "=     INSTALL CERTIFICATES    ="
#     echo -e "===============================\n"

#     # Install OpenShift cert-manager operator
#     oc apply -f https://raw.githubusercontent.com/alvarolop/ocp-secured-integration/refs/heads/main/application-02-cert-manager-operator.yaml

#     echo -n "Waiting for operator pods to be ready..."
#     while [[ $(oc get pods -l name=cert-manager-operator -n cert-manager-operator -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

#     echo -n "Waiting for cert-manager pods to be ready..."
#     while [[ $(oc get pods -l app.kubernetes.io/instance=cert-manager -n cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True True True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

#     # Configure API and Ingress certificates (It user the $CLUSTER_DOMAIN defined previously)
#     # Retrieve the cluster domain
#     curl -s https://raw.githubusercontent.com/alvarolop/ocp-secured-integration/main/application-02-cert-manager-route53.yaml | CLUSTER_DOMAIN=$(oc get dns.config/cluster -o jsonpath='{.spec.baseDomain}') envsubst | oc apply -f -

#     sleep 10 # Wait for the Certificates to be created in the cluster

#     echo -ne "\nWaiting for ocp-api certificate to be ready..."
#     while [[ $(oc get certificate ocp-api -n openshift-config -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 5; done; echo -n -e "  [OK]\n"

#     echo -ne "\nWaiting for ocp-ingress certificate to be ready..."
#     while [[ $(oc get certificate ocp-ingress -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 5; done; echo -n -e "  [OK]\n"

#     sleep 10

#     # Check cluster operators status
#     set +e  # Disable exit on non-zero status to keep the script running even if commands fail. There is no HA when cluster is SNO
#     echo -e "\nCheck cluster operators..."
#     while true; do
#         oc get clusteroperators
#         STATUS_AUTHENTICATION=$(oc get clusteroperators authentication -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
#         STATUS_CONSOLE=$(oc get clusteroperators console -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
#         STATUS_KUBE_API_SERVER=$(oc get clusteroperators kube-apiserver -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
#         STATUS_KUBE_SCHEDULER=$(oc get clusteroperators kube-scheduler -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')
#         STATUS_KUBE_CONTROLLER_MANAGER=$(oc get clusteroperators kube-controller-manager -o go-template='{{range .status.conditions}}{{ if eq .type "Progressing"}}{{.status}}{{end}}{{end}}')

#         # echo "STATUS_AUTHENTICATION $STATUS_AUTHENTICATION"
#         # echo "STATUS_CONSOLE $STATUS_CONSOLE"
#         # echo "STATUS_KUBE_API_SERVER $STATUS_KUBE_API_SERVER"
#         # echo "STATUS_KUBE_SCHEDULER $STATUS_KUBE_SCHEDULER"
#         # echo "STATUS_KUBE_CONTROLLER_MANAGER $STATUS_KUBE_CONTROLLER_MANAGER"

#         if [ $STATUS_AUTHENTICATION == "False" ] && [ $STATUS_CONSOLE == "False" ] && [ $STATUS_KUBE_API_SERVER == "False" ] && [ $STATUS_KUBE_SCHEDULER == "False" ] && [ $STATUS_KUBE_CONTROLLER_MANAGER == "False" ]; then
#             echo -e "\n\tOperators updated!!\n"
#             break
#         fi

#         echo -e "Cluster operators are still progressing...Sleep 60s...\n"
#         sleep 60
#     done

# fi


if [[ "$INSTALL_OPENSHIFT_LIGHTSPEED" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then

    echo -e "\n================================="
    echo -e "=     INSTALL OCP LIGHTSPEED    ="
    echo -e "=================================\n"

    checkVariable "OLS_PROVIDER_NAME"
    checkVariable "OLS_PROVIDER_MODEL_NAME"
    checkVariable "OLS_PROVIDER_TYPE"
    checkVariable "OLS_PROVIDER_API_URL"
    checkVariable "OLS_PROVIDER_API_TOKEN"

    cat application-ocp-lightspeed.yaml | \
    OLS_PROVIDER_NAME=$OLS_PROVIDER_NAME OLS_PROVIDER_MODEL_NAME=$OLS_PROVIDER_MODEL_NAME \
    OLS_PROVIDER_TYPE=$OLS_PROVIDER_TYPE OLS_PROVIDER_API_URL=$OLS_PROVIDER_API_URL \
    OLS_PROVIDER_API_TOKEN=$OLS_PROVIDER_API_TOKEN envsubst | oc apply -f -
fi


# Print values to access the cluster

OCP_CONSOLE=https://console-openshift-console.apps.$CLUSTER_NAME.$RHPDS_TOP_LEVEL_ROUTE53_DOMAIN

echo -e "\n==============================="
echo -e "=   Installation finished!!!  ="
echo -e "===============================\n"
echo -e "\nYou can access the cluster using the console or the CLI"
echo -e "\t* Web: $OCP_CONSOLE"
echo -e "\t* CLI: oc login -u ${K_DEFAULT_USER} $OCP_API # You can use any other user"
echo ""
