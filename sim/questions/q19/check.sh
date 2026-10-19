#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
C="cronjob rigel-report -n rigel"
J="job rigel-report-manual -n rigel"
T='{.spec.jobTemplate.spec.template.spec'

schedule_ok() {
  case "$(jp $C -o jsonpath='{.spec.schedule}')" in
    "*/15 * * * *" | "0,15,30,45 * * * *" | "0/15 * * * *") return 0 ;;
  esac
  return 1
}
container_ok() {
  local out
  out=$(jp $C -o jsonpath="$T.containers[0].image}|$T.containers[0].command} $T.containers[0].args}")
  [ "${out%%|*}" = "busybox:1.37" ] && has "$out" "echo report generated"
}
from_cronjob() {
  [ "$(jp $J -o jsonpath='{.metadata.ownerReferences[?(@.kind=="CronJob")].name}')" = "rigel-report" ] ||
    [ "$(jp $J -o jsonpath='{.metadata.annotations.cronjob\.kubernetes\.io/instantiate}')" = "manual" ]
}

check "CronJob rigel-report exists in rigel" jp $C
check "schedule runs every 15 minutes" schedule_ok
check "image busybox:1.37 running the report command" container_ok
check "concurrencyPolicy is Forbid" is "$(jp $C -o jsonpath='{.spec.concurrencyPolicy}')" "Forbid"
check "keeps 2 successful and 1 failed Job" \
  is "$(jp $C -o jsonpath='{.spec.successfulJobsHistoryLimit} {.spec.failedJobsHistoryLimit}')" "2 1"
check "startingDeadlineSeconds is 60" is "$(jp $C -o jsonpath='{.spec.startingDeadlineSeconds}')" "60"
check "restartPolicy is OnFailure" is "$(jp $C -o jsonpath="$T.restartPolicy}")" "OnFailure"
check "Job rigel-report-manual was created from the CronJob" from_cronjob
check "Job rigel-report-manual completed" is "$(jp $J -o jsonpath='{.status.succeeded}')" "1"
check "manual.log contains the report output" file_has "$COURSE/19/manual.log" "report generated"

finish
