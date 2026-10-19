#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl patch cronjob scutum-backup -n scutum --type=merge -p \
  '{"spec":{"schedule":"0 */6 * * *","timeZone":"Europe/Paris","suspend":false,"successfulJobsHistoryLimit":1,"failedJobsHistoryLimit":1}}'
kubectl create job scutum-backup-now -n scutum --from=cronjob/scutum-backup
kubectl wait --for=condition=complete job/scutum-backup-now -n scutum --timeout=120s
kubectl logs -n scutum job/scutum-backup-now >/opt/course/34/backup.log
