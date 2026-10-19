#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl get ns -l nimbus.io/team -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' >/opt/course/1/team-namespaces
kubectl get pods -A -l tier=frontend --no-headers | wc -l >/opt/course/1/frontend-pods
pod=$(kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.annotations.nimbus\.io/role=="primary")]}{.spec.nodeName}{end}')
echo "$pod" >/opt/course/1/primary-node
