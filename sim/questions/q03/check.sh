#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
J="job checksum-job -n draco"

check "/opt/course/3/job.yaml is a Job manifest" file_has "$COURSE/3/job.yaml" "kind: Job"
check "Job checksum-job exists in draco" jp $J
check "completions is 6" is "$(jp $J -o jsonpath='{.spec.completions}')" "6"
check "parallelism is 2" is "$(jp $J -o jsonpath='{.spec.parallelism}')" "2"
check "activeDeadlineSeconds is 120" is "$(jp $J -o jsonpath='{.spec.activeDeadlineSeconds}')" "120"
check "container is named checksum, image busybox:1.37" \
  is "$(jp $J -o jsonpath='{.spec.template.spec.containers[0].name} {.spec.template.spec.containers[0].image}')" "checksum busybox:1.37"
check "Pods carry label job-group=checksum" is "$(jp $J -o jsonpath='{.spec.template.metadata.labels.job-group}')" "checksum"
check "Job completed 6 times" is "$(jp $J -o jsonpath='{.status.succeeded}')" "6"
check "job.log contains the Pod output" file_has "$COURSE/3/job.log" "checksum ok"

finish
