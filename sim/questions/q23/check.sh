#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
L=$COURSE/23/legacy

api_is() { grep -qE "^apiVersion:[[:space:]]*\"?$2\"?[[:space:]]*\$" "$1"; }
hpa_ok() {
  is "$(jp hpa pollux-web -n pollux -o jsonpath='{.spec.scaleTargetRef.name} {.spec.minReplicas} {.spec.maxReplicas}')" "pollux-web 2 5" &&
    is "$(jp hpa pollux-web -n pollux -o jsonpath='{.spec.metrics[?(@.resource.name=="cpu")].resource.target.averageUtilization}')" "70"
}

check "Backup nightly exists in pollux" jp backups.nimbus.io nightly -n pollux
check "nightly: schedule 0 2 * * *, retentionDays 7, target pollux-web" \
  is "$(jp backups.nimbus.io nightly -n pollux -o jsonpath='{.spec.schedule}|{.spec.retentionDays}|{.spec.target}')" "0 2 * * *|7|pollux-web"
check "short-name contains bk" is "$(tr -d '[:space:]' <"$COURSE/23/short-name" 2>/dev/null)" "bk"
check "legacy/hpa.yaml uses autoscaling/v2" api_is "$L/hpa.yaml" "autoscaling/v2"
check "legacy/pdb.yaml uses policy/v1" api_is "$L/pdb.yaml" "policy/v1"
check "HPA pollux-web scales pollux-web 2-5 at 70% CPU" hpa_ok
check "PDB pollux-web keeps 1 Pod of app=pollux-web available" \
  is "$(jp pdb pollux-web -n pollux -o jsonpath='{.spec.minAvailable} {.spec.selector.matchLabels.app}')" "1 pollux-web"

finish
