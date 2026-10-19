#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 13 >/dev/null
reset_ns centaurus
# Remove volumes provisioned for earlier attempts.
for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="centaurus")]}{.metadata.name}{"\n"}{end}'); do
  kubectl delete pv "$pv" --ignore-not-found --wait=false
done
