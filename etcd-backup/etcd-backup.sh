#! /bin/bash

BACKUP_DIR="/tmp/ocp-backup"
MASTER_0_NAME=$(oc get nodes -l node-role.kubernetes.io/master -o go-template='{{ (index .items 0).metadata.name }}')

if [[ ! -d "${BACKUP_DIR}" ]]; then
  mkdir "${BACKUP_DIR}"
  if [[ ${res} -ne 0 ]]; then
    echo "Failed to create OCP backup directory."
    exit ${res}
  fi
fi

ssh -i /home/kni/.ssh/openshift_rsa core@"${MASTER_0_NAME}" 'sudo -E rm ./assets/backup/*'
ssh -i /home/kni/.ssh/openshift_rsa core@"${MASTER_0_NAME}" 'sudo -E /usr/local/bin/cluster-backup.sh ./assets/backup'
ssh -i /home/kni/.ssh/openshift_rsa core@"${MASTER_0_NAME}" 'sudo -E chmod 644 ./assets/backup/*'
scp -i /home/kni/.ssh/openshift_rsa core@"${MASTER_0_NAME}":/home/core/assets/backup/* "${BACKUP_DIR}"
