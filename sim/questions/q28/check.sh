#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"

# reaches NS DEPLOY URL : a Pod of DEPLOY in NS gets an nginx page from URL.
reaches() {
  kubectl exec -n "$1" "deploy/$2" -- wget -qO- -T 3 "$3" 2>/dev/null | grep -q "Welcome to nginx"
}

policies_ok() {
  reaches hydrus web http://cache &&
    is "$(jp netpol default-deny -n hydrus -o jsonpath='{.spec.podSelector}|{.spec.policyTypes}|{.spec.ingress}')" '{}|["Ingress"]|' &&
    is "$(jp netpol -n hydrus -o name | sort | tr '\n' ' ')" "networkpolicy.networking.k8s.io/cache-access networkpolicy.networking.k8s.io/default-deny "
}
check "default-deny unchanged and no extra policies in hydrus" policies_ok
check "web Pods reach cache:80" reaches hydrus web http://cache
check "web was fixed with a label, not by loosening cache-access" \
  is "$(jp deploy web -n hydrus -o jsonpath='{.spec.template.metadata.labels.role}')" "cache-client"
check "hydrus-monitoring app=metrics Pods reach cache:80" reaches hydrus-monitoring metrics http://cache.hydrus
not_debug() { reaches hydrus-monitoring metrics http://cache.hydrus && ! reaches hydrus-monitoring debug http://cache.hydrus; }
check "other hydrus-monitoring Pods (debug) are still blocked" not_debug

finish
