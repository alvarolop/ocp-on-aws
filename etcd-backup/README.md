# Backing up etcd


    # Annex: Etcd backups

    Back up your cluster’s etcd data regularly and store in a secure location ideally outside the OpenShift Container Platform environment.

    [>>> CLICK HERE <<<](./docs/etcd-backup/README.md)

    <!-- ![alt text](docs/images/app-of-apps.png) -->


`etcd` is the key-value store for OpenShift Container Platform, which persists the state of all resource objects. Back up your cluster's etcd data regularly and store in a secure location ideally outside the OpenShift Container Platform environment. We have created two different mechanisms to execute backups.

Documentation about etcd backups is [here](https://docs.openshift.com/container-platform/4.16/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html). 


## Manual ETCD Backup

First option is to execute the backup process manually. For that, we can use the following script:

```bash
aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | "\(.Tags[] | select(.Key == "Name").Value) \(.State.Name) \(.PublicDnsName)"' 
```

```bash
./etcd-backup.sh
```


## Automated ETCD Backup

As we want to do it in an automated fashion, we will create the following k8s resources:

* **Namespace** to run the backup in it.
* **Service Account** that will be responsible for performing backup commands for the master nodes.
* **Cluster Role** as a security measure with specific permissions for running the backup.
* **Cluster Role Binding** to link the Cluster Role to the Service Account.
* **Set Privileges for Service Account** using an SCC `privileged` as the commands are executed with `sudo`.
* **CronJob** using the OpenShift client image to create the backup and debug pods.


```bash
source aws-ocp4-config-labs
./etcd-backup/aws-create-bucket.sh etcd-backup-alvaro
```


Create all the resources with the following command:

```bash
oc create secret generic ssh-key-secret -n etcd-backup \
--from-file=id_rsa=/home/$USER/.ssh/id_rsa \
--from-file=id_rsa.pub=/home/$USER/.ssh/id_rsa.pub

oc apply -k etcd-backup/gitops
```


You can force the backup using the following command:

```bash
oc delete job backup -n etcd-backup
oc apply -k etcd-backup/gitops
oc create job backup --from=cronjob/etcd-backup -n etcd-backup
```


You can find more information in the following documentation:

* https://www.redhat.com/en/blog/ocp-disaster-recovery-part-1-how-to-create-automated-etcd-backup-in-openshift-4.x[Documentation: Backing up etcd].
* Blog: https://www.redhat.com/en/blog/ocp-disaster-recovery-part-1-how-to-create-automated-etcd-backup-in-openshift-4.x[OCP Disaster Recovery Part 1 - How to Create Automated ETCD Backup in Openshift 4.x].







https://github.com/alvarolop/quarkus-observability-app/blob/main/dockerfile-aws/Dockerfile