#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod auditor -n polaris"

check "Dockerfile sets ROLE to auditor" grep -qE 'ROLE[= ]"?auditor"?([[:space:]]|$)' "$COURSE/11/image/Dockerfile"

tags_pushed() {
  grep -qE 'ROLE[= ]"?auditor"?([[:space:]]|$)' "$COURSE/11/image/Dockerfile" || return 1  # tags survive resets
  local tags
  tags=$(curl -s http://k3d-ckad-registry:5000/v2/nimbus-auditor/tags/list)
  has "$tags" '"v1"' && has "$tags" '"latest"'
}
check "tags v1 and latest are in the registry" tags_pushed
check "Pod auditor uses localhost:5000/nimbus-auditor:v1" \
  is "$(jp $P -o jsonpath='{.spec.containers[0].image}')" "localhost:5000/nimbus-auditor:v1"
check "Pod auditor is Running" is "$(jp $P -o jsonpath='{.status.phase}')" "Running"
check "logs file shows role=auditor build=v1" file_has "$COURSE/11/logs" "role=auditor build=v1"

tar_ok() {
  local f=$COURSE/11/nimbus-auditor-v1.tar
  [ -s "$f" ] && tar -tf "$f" 2>/dev/null | grep -qE '^(manifest|index)\.json$'
}
check "image exported as a tar archive to nimbus-auditor-v1.tar" tar_ok

finish
