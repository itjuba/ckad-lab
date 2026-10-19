#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
PV="pv andromeda-pv"
PVC="pvc andromeda-pvc -n andromeda"
D="deploy andromeda-store -n andromeda"
T='{.spec.template.spec'

check "PV andromeda-pv: 1Gi, ReadWriteOnce, hostPath /mnt/andromeda-data" \
  is "$(jp $PV -o jsonpath='{.spec.capacity.storage} {.spec.accessModes[*]} {.spec.hostPath.path}')" "1Gi ReadWriteOnce /mnt/andromeda-data"
check "PV has no StorageClass" bash -c '[ -n "$(kubectl get pv andromeda-pv -o name)" ] &&
  [ -z "$(kubectl get pv andromeda-pv -o jsonpath="{.spec.storageClassName}")" ]'
check "PVC andromeda-pvc requests 1Gi ReadWriteOnce" \
  is "$(jp $PVC -o jsonpath='{.spec.resources.requests.storage} {.spec.accessModes[*]}')" "1Gi ReadWriteOnce"
check "PVC is Bound to andromeda-pv" is "$(jp $PVC -o jsonpath='{.status.phase} {.spec.volumeName}')" "Bound andromeda-pv"

mounted() {
  local vol
  vol=$(jp $D -o jsonpath="$T.volumes[?(@.persistentVolumeClaim.claimName==\"andromeda-pvc\")].name}")
  [ -n "$vol" ] &&
    is "$(jp $D -o jsonpath="$T.containers[0].volumeMounts[?(@.name==\"$vol\")].mountPath}")" "/usr/local/apache2/htdocs"
}
check "Deployment andromeda-store mounts the claim at /usr/local/apache2/htdocs" mounted
check "Deployment uses httpd:2.4-alpine and is available" \
  bash -c 'r=$(kubectl get deploy andromeda-store -n andromeda -o jsonpath="{.spec.template.spec.containers[0].image} {.spec.replicas} {.status.availableReplicas}");
  set -- $r; [ "$1" = httpd:2.4-alpine ] && [ -n "$3" ] && [ "$2" = "$3" ]'

finish
