#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
NP="networkpolicy -n altair"

# reach FROM URL : wget from a Pod of deployment FROM succeeds.
reach() { kubectl exec -n altair "deploy/$1" -- wget -qO- -T 3 "$2" >/dev/null 2>&1; }
blocked() { ! reach "$@"; }

default_deny() {
  jp $NP default-deny-ingress >/dev/null &&
    [ "$(jp $NP default-deny-ingress -o jsonpath='{.spec.podSelector}')" = "{}" ] &&
    has "$(jp $NP default-deny-ingress -o jsonpath='{.spec.policyTypes}')" "Ingress" &&
    [ -z "$(jp $NP default-deny-ingress -o jsonpath='{.spec.ingress}')" ]
}
named_policies() { jp $NP allow-api allow-db api-egress >/dev/null; }
dns_ok() { kubectl exec -n altair deploy/api -- timeout 10 nslookup db.altair.svc.cluster.local >/dev/null 2>&1; }

check "default-deny-ingress selects every Pod and allows no ingress" default_deny
check "NetworkPolicies allow-api, allow-db and api-egress exist" named_policies
guarded() { named_policies && default_deny && "$@"; }
check "frontend can reach api" guarded reach frontend http://api
check "admin can't reach api" blocked admin http://api
check "frontend can't reach db" blocked frontend http://db
check "api can reach db" guarded reach api http://db
check "api can still resolve DNS names" guarded dns_ok
check "api can't reach anything else (collector.altair-monitoring)" guarded blocked api http://collector.altair-monitoring

finish
