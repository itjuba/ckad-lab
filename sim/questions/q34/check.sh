#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
CJ="cronjob scutum-backup -n scutum"
J="job scutum-backup-now -n scutum"

schedule_ok() {
  case "$(jp $CJ -o jsonpath='{.spec.schedule}' | tr -s ' ')" in
    "0 */6 * * *" | "0 0/6 * * *" | "0 0,6,12,18 * * *") return 0 ;;
  esac
  return 1
}
check "schedule runs every 6 hours at minute 0" schedule_ok
check "timeZone is Europe/Paris" is "$(jp $CJ -o jsonpath='{.spec.timeZone}')" "Europe/Paris"

resumed() { jp $CJ >/dev/null && [ "$(jp $CJ -o jsonpath='{.spec.suspend}')" != "true" ]; }
check "CronJob is no longer suspended" resumed
check "history keeps 1 successful and 1 failed Job" \
  is "$(jp $CJ -o jsonpath='{.spec.successfulJobsHistoryLimit}/{.spec.failedJobsHistoryLimit}')" "1/1"

from_cronjob() {
  [ "$(jp $J -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}')" = "CronJob/scutum-backup" ] ||
    [ "$(jp $J -o jsonpath='{.metadata.annotations.cronjob\.kubernetes\.io/instantiate}')" = "manual" ]
}
job_ok() { from_cronjob && is "$(jp $J -o jsonpath='{.status.succeeded}')" "1"; }
check "Job scutum-backup-now was created from the CronJob and completed" job_ok
check "backup.log contains the Job output" file_has "$COURSE/34/backup.log" "backup done"

finish
