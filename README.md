# OCP 4 basic installation on AWS

This repository contains a set of scripts that would facilitate the provisioning and configuration of an OCP 4 cluster on AWS.

> [!CAUTION]
> This is not intended for production usage. 

## AWS account

In order to install OpenShift on AWS using IPI (Installer-Provisioned Infrastructure), you need the following configuration:

* An AWS account.
* A domain name registered with a registrar. You can register a domain directly through Route 53 or use another domain registrar.
* To configure the top-level domain in AWS Route 53, create a hosted zone for your domain, update the registrar with the provided NS records, and then add the necessary DNS records like A or CNAME to point to your infrastructure. This setup links your domain to Route 53, allowing you to manage DNS for your website or services.

> [!IMPORTANT]
> If you are a Red Hatter, you can order a lab environment on the (Red Hat Demo Platform)[https://demo.redhat.com/]. Request environment `Red Hat Open Environments` > `AWS Blank Open Environment`


## Prerequisites

**Create a copy** and **modify** [aws-ocp4-config](aws-ocp4-config) file. This file contains required config data used by the installation script to provision and configure the new OCP 4 cluster. Use the new file as source of configuration for the installation.

Ex: `cp aws-ocp4-config aws-ocp4-config-labs`

AWS and installation parameters that you are required to modify:

- **RHPDS_GUID**: RHPDS Lab GUID. You can find it on the email.
- **AWS_ACCESS_KEY_ID**: You can find it on the email.
- **AWS_SECRET_ACCESS_KEY**: You can find it on the email.
- **AWS_DEFAULT_REGION**: This is the region where your cluster will be deployed. I recommend `eu-west-1` to simplify automation of further components.
- **RHOCM_PULL_SECRET**: Enter Pull Secret given from RedHat OpenShift Cluster Manager [site](https://console.redhat.com/openshift/create) for an AWS IPI installation
- **WORKDIR**: Base path for directory where all binaries and configuration for the cluster will be placed. Ex: `$(pwd)/ocp4-sandbox${RHPDS_GUID}`


OCP parameters to configure your cluster:

- **OPENSHIFT_VERSION**: OCP installer binary version. Check versions available [here](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/) Ex: `4.9.4`
- **MASTER_INSTANCE_TYPE**: AWS EC2 instance type for masters nodes. Minimum is `m5.xlarge`.
- **WORKER_INSTANCE_TYPE**: AWS EC2 instance type for workers nodes. Ex: `m5.large`
- **WORKER_REPLICAS**: Number of worker replicas. Ex: `3`
- **INSTALL_LETS_ENCRYPT_CERTIFICATES**: This script automatically configures Let's Encrypt certificates for both the OCP API and the Ingress controllers. Configure it setting the boolean from `True` to `False`. By default, it is set to `True`. For more information about this process, check this Openshift blog [entry](https://www.openshift.com/blog/requesting-and-installing-lets-encrypt-certificates-for-openshift-4) and [git repository](https://github.com/redhat-cop/openshift-lab-origin/blob/master/OpenShift4/Lets_Encrypt_Certificates_for_OCP4.adoc).
- **CLUSTER_NAME**: Unique cluster name, that will be part of cluster domain. Ex: `ocp` that would lead to a `ocp.sandbox${RHPDS_GUID}.opentlc.com` cluster domain.


## Single-node OpenShift

Ok, a full cluster (Multi-node cluster) is too much for your needs and you would like to deploy SNO on AWS using IPI installation? That's fine, this is your repo! 😀 These are the only changes that you have to apply to your configuration file:

* Set `WORKER_REPLICAS=0`.
* Set `MASTER_REPLICAS=1`.
* Increase the node size, as now it runs everything there `MASTER_INSTANCE_TYPE=m7i.4xlarge` (It could work with `2xlarge`, but you wouldn't have space for anything else).
* Optional, you can change the `CLUSTER_NAME="sno"` to sno and you will see how the url now contains `sno` in the name instead of `ocp`.

That's all! Execute it now and you will see the magic!! 🪄



Here, you can check the [official documentation](https://docs.openshift.com/container-platform/4.16/installing/installing_sno/install-sno-installing-sno.html#install-sno-monitoring-the-installation-manually_install-sno-installing-sno-with-the-assisted-installer) if you want to make further customizations.


## Cluster installation

The installation process is meant to create an installation directory where it will place all necessary binaries to run the full OCP 4 cluster provisioning and users configuration (Notice that you may already have some tools such as aws or oc cli installed on your machine, but the installation process will keep these new binaries isolated under the `$WORKDIR` directory).

Summary of tasks that are executed:

1. Download and install AWS cli.
2. Download OCP 4 installer.
3. Create OCP 4 basic installation config file.
4. Run OCP 4 installer.
5. Download and `untar` OC cli (required for next task).
6. Create a set of users in OCP.

To run the installation, once all prerequisites are fulfilled, run:

`./aws-ocp4-install.sh <CONFIG_FILE>`

Ex: `./aws-ocp4-install.sh  ./aws-ocp4-config-labs`

Once the OCP 4 cluster is installed, try to login using any of the users mentioned above.

**IMPORTANT:** Please, keep this new directory `$WORKDIR-$CLUSTER_NAME` save to be able to perform a complete automated cluster deprovisioning.

## Cluster deprovisioning

In order to destroy the full cluster, the ocp installer requires some variables and metadata files generated during the installation process. To completely remove the cluster, run:

`./aws-ocp4-destroy.sh <CLUSTER_DIRECTORY>`

Ex: `./aws-ocp4-destroy.sh  ~/ocp4-sandbox932`

where `<CLUSTER_DIRECTORY>` is the same as the one used during installation (that is `$WORKDIR-$CLUSTER_NAME`)

## Start/Stop EC2 instances

In order to save some $€, **do not forget to stop** all the EC2 instances running for that given cluster. To facilitate the process, run:

`./aws-ocp4-stop-ec2.sh <CLUSTER_DIRECTORY>`

Ex: `./aws-ocp4-stop-ec2.sh  ~/ocp4-sandbox932`

Once you need to **start the EC2 cluster instances** again, run:

`./aws-ocp4-start-ec2.sh <CLUSTER_DIRECTORY>`

Ex: `./aws-ocp4-start-ec2.sh  ~/ocp4-sandbox932`

Keep also in mind that if you **don't need the cluster anymore, please, deprovision it!!!**


# Annex: Add users to the OCP cluster prior to the installation

`htpasswd -b -B auth/users.htpasswd myusername mypassword`

After that, you can update the credentials secret in OCP using the following commands:

```bash
oc delete secret htpass-secret -n openshift-config
oc create secret generic htpass-secret -n openshift-config --from-file=htpasswd=auth/users.htpasswd
oc adm policy add-cluster-role-to-user cluster-admin myusername
```
