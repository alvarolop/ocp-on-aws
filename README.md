# OCP 4 basic installation on AWS

This repository contains a set of scripts that would facilitate the provisioning and configuration of an OCP 4 cluster on AWS.

1. [OCP 4 basic installation on AWS](#ocp-4-basic-installation-on-aws)
   1. [Prerequisites](#prerequisites)
      1. [0. Command line utilities](#0-command-line-utilities)
      2. [1. AWS account](#1-aws-account)
      3. [2. Authentication configuration](#2-authentication-configuration)
      4. [3. Add it all to the config file](#3-add-it-all-to-the-config-file)
   2. [Single-node OpenShift](#single-node-openshift)
   3. [Multiple OCP clusters](#multiple-ocp-clusters)
   4. [Cluster installation](#cluster-installation)
   5. [Cluster Operations](#cluster-operations)
      1. [Cluster deprovisioning](#cluster-deprovisioning)
      2. [Start/Stop EC2 instances](#startstop-ec2-instances)
   6. [OpenShift GitOps deployment](#openshift-gitops-deployment)
   7. [OpenShift Lightspeed](#openshift-lightspeed)
2. [Annex: Add users to OCP cluster after install](#annex-add-users-to-ocp-cluster-after-install)
3. [Annex: Recover from expired certificates](#annex-recover-from-expired-certificates)


> [!CAUTION]
> This is not intended for production usage. 


## Prerequisites

### 0. Command line utilities

* If you want to define your own users, you will need to use the `htpasswd` cli. This command is provided by the `httpd-tools` package on RHEL/Fedora systems. If not, you can just use the example `users.htpasswd` file that has the `redhat` user with password `redhat!1`.

### 1. AWS account


In order to install OpenShift on AWS using IPI (Installer-Provisioned Infrastructure), you need the following configuration:

* An AWS account.
* A domain name registered with a registrar. You can register a domain directly through Route 53 or use another domain registrar.
* To configure the top-level domain in AWS Route 53, create a hosted zone for your domain, update the registrar with the provided NS records, and then add the necessary DNS records like A or CNAME to point to your infrastructure. This setup links your domain to Route 53, allowing you to manage DNS for your website or services.

> [!IMPORTANT]
> If you are a Red Hatter, you can order a lab environment on the [Red Hat Demo Platform](https://catalog.demo.redhat.com/catalog?item=babylon-catalog-prod/sandboxes-gpte.sandbox-open.prod&utm_source=webapp&utm_medium=share-link). Request environment `Red Hat Open Environments` > `AWS Blank Open Environment`


### 2. Authentication configuration

> [!TIP]
> There is a shortcut for this section. If you don't want to define your own users. Leave the `users.htpasswd` and `group-cluster-admins.yaml` files undefined. The automation will create a temporary `htpasswd` file for a random password for a `redhat` user. This user will be `cluster-admin` in your installation.

This automation will automatically create certain users on the cluster and add then to the `cluster-admin` role. In order to automate that, you have the `auth` folder with all the configuration. Please, you need to update two files:

* Copy the `users.htpasswd.example` file to `users.htpasswd` inside the `auth` folder to store the hash credentials. You can add users with the following command: `htpasswd -b -B auth/users.htpasswd myusername mypassword`.


* Copy the `group-cluster-admins.yaml.example` file to `group-cluster-admins.yaml` inside the `auth` folder and add the users you want to give `cluster-admin` to.


### 3. Add it all to the config file

**Create a copy** and **modify** [aws-ocp4-config](aws-ocp4-config) file. This file contains required config data used by the installation script to provision and configure the new OCP 4 cluster. Use the new file as source of configuration for the installation.

Ex: `cp aws-ocp4-config aws-ocp4-config-labs`

AWS and installation parameters that **you are required to modify**:

* **RHPDS_TOP_LEVEL_ROUTE53_DOMAIN**: Top level route53 domain. You can find it on the email.
* **AWS_ACCESS_KEY_ID**: You can find it on the email.
* **AWS_SECRET_ACCESS_KEY**: You can find it on the email.
* **AWS_DEFAULT_REGION**: This is the region where your cluster will be deployed. I recommend `eu-west-1` to simplify automation of further components.
* **RHOCM_PULL_SECRET**: Enter Pull Secret given from RedHat OpenShift Cluster Manager [site](https://console.redhat.com/openshift/create) for an AWS IPI installation


OCP parameters to configure your cluster. **These are optional, as you can use the defaults**:

- **OPENSHIFT_VERSION**: OCP installer binary version. Check versions available [here](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/) Ex: `4.18.6`.
- **MASTER_INSTANCE_TYPE**: AWS EC2 instance type for masters nodes. Minimum is `m7i.2xlarge`.
- **WORKER_INSTANCE_TYPE**: AWS EC2 instance type for workers nodes. Ex: `m7i.xlarge`
- **WORKER_REPLICAS**: Number of worker replicas. Ex: `1`
- **INSTALL_LETS_ENCRYPT_CERTIFICATES**: This script automatically configures Let's Encrypt certificates for both the OCP API and the Ingress controllers. Configure it setting the boolean from `True` to `False`. By default, it is set to `True`. For more information about this process, check this Openshift blog [entry](https://www.openshift.com/blog/requesting-and-installing-lets-encrypt-certificates-for-openshift-4) and [git repository](https://github.com/redhat-cop/openshift-lab-origin/blob/master/OpenShift4/Lets_Encrypt_Certificates_for_OCP4.adoc).
- **CLUSTER_NAME**: Unique cluster name, that will be part of cluster domain. Ex: `ocp` that would lead to a `ocp.sandbox${RHPDS_GUID}.opentlc.com` cluster domain.


## Single-node OpenShift

Ok, a full cluster (Multi-node cluster) is too much for your needs and you would like to deploy SNO on AWS using IPI installation? That's fine, this is your repo! 😀 These are the only changes that you have to apply to your configuration file:

* Set `WORKER_REPLICAS=0`.
* Set `MASTER_REPLICAS=1`.
* Increase the node size, as now it runs everything there `MASTER_INSTANCE_TYPE=m7i.4xlarge` (It could work with `2xlarge`, but you wouldn't have space for anything else).
* Optional, you can change the `CLUSTER_NAME="sno"` to sno and you will see how the url now contains `sno` in the name instead of `ocp`.

That's all! Execute it now and you will see the magic!! 🪄

Here, you can check the [official documentation](https://docs.openshift.com/container-platform/4.18/installing/installing_sno/install-sno-installing-sno.html#install-sno-monitoring-the-installation-manually_install-sno-installing-sno-with-the-assisted-installer) if you want to make further customizations.


> [!CAUTION]
> `AWS Blank Open Environment` accounts have a default Service Quota of **Classic Load Balancers per Region = 20**. This means that you can only deploy this exercise for 15 users by default. Rise the Quota to 40 to ensure that you can at least deploy 20 clusters. For that, just follow these steps:
> 1. Sign in to the AWS Management Console.
> 2. Open the Service Quotas console.
> 3. In the navigation pane, choose AWS services and select Elastic Load Balancing.
> 4. Find the quota for `Application-` or `Classic Load Balancers per region` (e.g., 50 for Application Load Balancers per region) and request an increase.


## Multiple OCP clusters


> [!IMPORTANT]
> This section requires `aws` CLI. Remember to install it before executing the script!

In some cases, you would like to provision several OCP clusters to test ACM features, to prepare a workshop for your colleagues or simply to test an upgrade of an operator without disrupting your main cluster. You are lucky, because now this repository provides this feature, too!

The mechanism is simple. Suppose that you installed a cluster named `CLUSTER_NAME="ocp"` with three nodes, this will create several AWS networking components like ElasticIPs, a VPC and the subnets. If you plan to install a new cluster with the same account without modifying the default AWS account configuration, you will observe that the account runs out of ElasticIPs to provide to the new cluster and the installation fails. 

To avoid this issue, this installed provides a flag to reuse the same network elements from the previous cluster. For that, you will need to perform the following changes:

1. Change the cluster name so that there isn't conflicts:

```bash
CLUSTER_NAME="sno"
```

2. Enable the VPC reutilization and provide the name of the previous AWS subnet:

```bash
REUSE_AWS_VPC=true
EXISTING_VPC=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text)
```




## Cluster installation

The installation process is meant to create an installation directory where it will place all necessary binaries to run the full OCP 4 cluster provisioning and users configuration (Notice that you may already have some tools such as aws or oc cli installed on your machine, but the installation process will keep these new binaries isolated under the `$WORKDIR` directory).

Summary of tasks that are executed:

1. Download OCP 4 installer.
2. Create OCP 4 basic installation config file.
3. Run OCP 4 installer.
4. Download and `untar` OC cli (required for next task).
5. Create a set of users in OCP.
6. Install Let's Encrypt certificates.
7. Install and configure GitOps.

To run the installation, once all prerequisites are fulfilled, run:

`./aws-ocp4-install.sh <CONFIG_FILE>`

Ex: `./aws-ocp4-install.sh  ./aws-ocp4-config-labs`

Once the OCP 4 cluster is installed, try to login using any of the users mentioned above.

**IMPORTANT:** Please, keep this new directory `$WORKDIR-$CLUSTER_NAME` save to be able to perform a complete automated cluster deprovisioning.

## Cluster Operations

### Cluster deprovisioning

In order to destroy the full cluster, the ocp installer requires some variables and metadata files generated during the installation process. To completely remove the cluster, run:

`./aws-ocp4-destroy.sh <CLUSTER_DIRECTORY>`

Ex: `./aws-ocp4-destroy.sh  ~/ocp4-sandbox932`

where `<CLUSTER_DIRECTORY>` is the same as the one used during installation (that is `$WORKDIR-$CLUSTER_NAME`)

### Start/Stop EC2 instances

In order to save some $€, **do not forget to stop** all the EC2 instances running for that given cluster. To facilitate the process, run:

`./aws-ocp4-stop-ec2.sh <CLUSTER_DIRECTORY>`

Ex: `./aws-ocp4-stop-ec2.sh  ~/ocp4-sandbox932`

Once you need to **start the EC2 cluster instances** again, run:

`./aws-ocp4-start-ec2.sh <CLUSTER_DIRECTORY>`

Ex: `./aws-ocp4-start-ec2.sh  ~/ocp4-sandbox932`

Keep also in mind that if you **don't need the cluster anymore, please, deprovision it!!!**


## OpenShift GitOps deployment

Currently all the clusters are configured using GitOps with ArgoCD. Therefore, I think that it is time to help customers to directly install ArgoCD right after installation. For that purpose, there is a new env var `INSTALL_OPENSHIFT_GITOPS` that will trigger the same installation that I provide in [alvarolop/ocp-gitops-playground](https://github.com/alvarolop/ocp-gitops-playground/tree/main).


## OpenShift Lightspeed

Well.. but I cannot live without AI!! Fine, then you should care about this section. The installer comes with an option to also configure [OpenShift Lightspeed](https://developers.redhat.com/products/openshift/lightspeed). OpenShift Lightspeed is a generative AI-based virtual assistant integrated into the OpenShift web console. If you want to add it to the automated installation, add the following variables to your configuration file:

```bash
INSTALL_OPENSHIFT_LIGHTSPEED=true
OLS_PROVIDER_NAME=<providerName>
OLS_PROVIDER_MODEL_NAME=<modelName>
OLS_PROVIDER_TYPE=<providerType>
OLS_PROVIDER_API_URL=<apiURL>
OLS_PROVIDER_API_TOKEN=<apiToken>
```

> [!TIP]
> If you are a Red Hatter, you can use the **Models-as-a-service for Parasol on OpenShift AI**. Ping me for more information!

If you want to install it manually on your cluster, you can do so directly using the `helm` command:

```bash
helm template ocp-lightspeed 
  --set providers[0].name="$OLS_PROVIDER_NAME" \
  --set providers[0].modelName="$OLS_PROVIDER_MODEL_NAME" \
  --set providers[0].type="$OLS_PROVIDER_TYPE" \
  --set providers[0].apiURL="$OLS_PROVIDER_API_URL" \
  --set providers[0].apiToken="$OLS_PROVIDER_API_TOKEN" | oc apply -f -
```


For more information about how to configure this feature, check the [official documentation](https://docs.openshift.com/lightspeed/1.0tp1/about/ols-about-openshift-lightspeed.html).


# Annex: Add users to OCP cluster after install


If you want to add users after installation, you can add users to the `htpasswd` file and then update the secret with the following commands:

```bash
oc delete secret htpass-secret -n openshift-config
oc create secret generic htpass-secret -n openshift-config --from-file=htpasswd=auth/users.htpasswd
oc adm policy add-cluster-role-to-user cluster-admin myusername
```


# Annex: Recover from expired certificates


```bash
for id in $(oc get csr | grep Pending | awk '{print $1}'); do
   oc adm certificate approve $id;
done
for id in $(oc --kubeconfig=kubeconfig --insecure-skip-tls-verify get csr | grep Pending | awk '{print $1}'); do
 oc --kubeconfig=kubeconfig --insecure-skip-tls-verify  adm certificate approve $id; 
done
```
