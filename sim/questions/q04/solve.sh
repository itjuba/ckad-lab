#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
helm uninstall vega-legacy -n vega
helm upgrade vega-api nimbus/webapp --version 0.2.0 -n vega --set replicaCount=2 --wait --timeout 120s
helm install vega-web nimbus/webapp --version 0.2.0 -n vega \
  --set replicaCount=3 --set service.type=NodePort --wait --timeout 120s
helm list -n vega --failed -q >/opt/course/4/failed-release
helm uninstall vega-canary -n vega
