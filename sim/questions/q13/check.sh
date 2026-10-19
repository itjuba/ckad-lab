#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
PVC="pvc centaurus-cache -n centaurus"
P="pod cache-writer -n centaurus"

check "PVC centaurus-cache: 500Mi, ReadWriteOnce, StorageClass local-path" \
  is "$(jp $PVC -o jsonpath='{.spec.resources.requests.storage} {.spec.accessModes[*]} {.spec.storageClassName}')" "500Mi ReadWriteOnce local-path"
check "status-before contains Pending" is "$(tr -d '[:space:]' <"$COURSE/13/status-before" 2>/dev/null)" "Pending"
check "pending-reason explains it waits for the first consumer" grep -qi "first consumer" "$COURSE/13/pending-reason"

pod_mounts() {
  local vol
  vol=$(jp $P -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim.claimName=="centaurus-cache")].name}')
  [ -n "$vol" ] &&
    is "$(jp $P -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name==\"$vol\")].mountPath}")" "/cache" &&
    is "$(jp $P -o jsonpath='{.spec.containers[0].image} {.status.phase}')" "busybox:1.37 Running"
}
check "Pod cache-writer (busybox:1.37) mounts the claim at /cache and is Running" pod_mounts

pv_name_ok() {
  local vn
  vn=$(jp $PVC -o jsonpath='{.spec.volumeName}')
  [ -n "$vn" ] && is "$(tr -d '[:space:]' <"$COURSE/13/pv-name")" "$vn"
}
check "pv-name contains the PV bound to the claim" pv_name_ok
check "/cache/date.log is being written" kubectl exec -n centaurus cache-writer -- test -s /cache/date.log

finish
