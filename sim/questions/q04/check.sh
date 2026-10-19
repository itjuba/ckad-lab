#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"

# gone RELEASE : helm no longer lists it (default listing shows deployed and failed).
gone() { ! helm list -n vega -q 2>/dev/null | grep -qx "$1"; }
# meta RELEASE FIELD : a field from `helm get metadata`, e.g. VERSION or STATUS.
meta() { helm get metadata "$1" -n vega 2>/dev/null | sed -n "s/^$2: *//p"; }
# deploy_of RELEASE JSONPATH : field of the Deployment the release created.
deploy_of() { jp deploy -n vega -l "app.kubernetes.io/instance=$1" -o jsonpath="{.items[0]$2}"; }
ready_is() { is "$(deploy_of "$1" .spec.replicas)/$(deploy_of "$1" .status.readyReplicas)" "$2/$2"; }

check "release vega-legacy is deleted" gone vega-legacy
check "vega-api runs chart version 0.2.0" is "$(meta vega-api VERSION) $(meta vega-api STATUS)" "0.2.0 deployed"
check "vega-api has 2 ready replicas" ready_is vega-api 2
check "vega-web is installed from webapp 0.2.0" is "$(meta vega-web CHART) $(meta vega-web VERSION) $(meta vega-web STATUS)" "webapp 0.2.0 deployed"
check "vega-web has 3 ready replicas" ready_is vega-web 3
check "vega-web Service is of type NodePort" \
  is "$(jp svc -n vega -l app.kubernetes.io/instance=vega-web -o jsonpath='{.items[0].spec.type}')" "NodePort"
check "failed-release contains vega-canary" is "$(tr -d '[:space:]' <"$COURSE/4/failed-release" 2>/dev/null)" "vega-canary"
check "release vega-canary is deleted" gone vega-canary

finish
