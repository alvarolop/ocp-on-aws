# OCP 4 basic installation on AWS

This repository contains a set of scripts that would facilitate the provisioning and configuration of an OCP 4 cluster on AWS.

- [OCP 4 basic installation on AWS](#ocp-4-basic-installation-on-aws)
  - [Prerequisites](#prerequisites)
    - [0. Command line utilities](#0-command-line-utilities)
    - [1. AWS account](#1-aws-account)
    - [2. Authentication configuration](#2-authentication-configuration)
    - [3. Add it all to the config file](#3-add-it-all-to-the-config-file)
  - [Single-node OpenShift](#single-node-openshift)
  - [Cluster installation](#cluster-installation)
  - [Cluster Operations](#cluster-operations)
    - [Cluster deprovisioning](#cluster-deprovisioning)
    - [Start/Stop EC2 instances](#startstop-ec2-instances)
  - [OpenShift GitOps deployment](#openshift-gitops-deployment)
- [Annex: Add users to OCP cluster after install](#annex-add-users-to-ocp-cluster-after-install)


> [!CAUTION]
> This is not intended for production usage. 


## Prerequisites

### 0. Command line utilities

* The certificates installation is based on `podman`, so please install `podman` cli prior to execute this script if you want the certificates configured. Check the [documentation](https://podman.io/docs/installation) for the installation mechanism on your system
* If you want to define your own users, you will need to use the `htpasswd` cli. This command is provided by the `httpd-tools` package on RHEL/Fedora systems. If not, you can just use the example `users.htpasswd` file that has the `redhat` user with password `redhat!1`.

### 1. AWS account


In order to install OpenShift on AWS using IPI (Installer-Provisioned Infrastructure), you need the following configuration:

* An AWS account.
* A domain name registered with a registrar. You can register a domain directly through Route 53 or use another domain registrar.
* To configure the top-level domain in AWS Route 53, create a hosted zone for your domain, update the registrar with the provided NS records, and then add the necessary DNS records like A or CNAME to point to your infrastructure. This setup links your domain to Route 53, allowing you to manage DNS for your website or services.

> [!IMPORTANT]
> If you are a Red Hatter, you can order a lab environment on the [Red Hat Demo Platform](https://demo.redhat.com). Request environment `Red Hat Open Environments` > `AWS Blank Open Environment`


### 2. Authentication configuration

This automation will automatically create certain users on the cluster and add then to the `cluster-admin` role. In order to automate that, you have the `auth` folder with all the configuration. Please, you need to update two files:

* Copy the `users.htpasswd.example` file to `users.htpasswd` inside the `auth` folder to store the hash credentials. You can add users with the following command: `htpasswd -b -B auth/users.htpasswd myusername mypassword`.


* Copy the `group-cluster-admins.yaml.example` file to `group-cluster-admins.yaml` inside the `auth` folder and add the users you want to give `cluster-admin` to.


### 3. Add it all to the config file

**Create a copy** and **modify** [aws-ocp4-config](aws-ocp4-config) file. This file contains required config data used by the installation script to provision and configure the new OCP 4 cluster. Use the new file as source of configuration for the installation.

Ex: `cp aws-ocp4-config aws-ocp4-config-labs`

AWS and installation parameters that **you are required to modify**:

* **RHPDS_GUID**: RHPDS Lab GUID. You can find it on the email.
* **AWS_ACCESS_KEY_ID**: You can find it on the email.
* **AWS_SECRET_ACCESS_KEY**: You can find it on the email.
* **AWS_DEFAULT_REGION**: This is the region where your cluster will be deployed. I recommend `eu-west-1` to simplify automation of further components.
* **RHOCM_PULL_SECRET**: Enter Pull Secret given from RedHat OpenShift Cluster Manager [site](https://console.redhat.com/openshift/create) for an AWS IPI installation


OCP parameters to configure your cluster. **These are optional, as you can use the defaults**:

- **OPENSHIFT_VERSION**: OCP installer binary version. Check versions available [here](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/) Ex: `4.17.7`.
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


Here, you can check the [official documentation](https://docs.openshift.com/container-platform/4.17/installing/installing_sno/install-sno-installing-sno.html#install-sno-monitoring-the-installation-manually_install-sno-installing-sno-with-the-assisted-installer) if you want to make further customizations.


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


# Annex: Add users to OCP cluster after install


If you want to add users after installation, you can add users to the `htpasswd` file and then update the secret with the following commands:

```bash
oc delete secret htpass-secret -n openshift-config
oc create secret generic htpass-secret -n openshift-config --from-file=htpasswd=auth/users.htpasswd
oc adm policy add-cluster-role-to-user cluster-admin myusername
```





