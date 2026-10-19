#!/usr/bin/env bash
# Container start: install the kubeconfig sim.ps1 generated, start the chart repo, idle.
mkdir -p /root/.kube /opt/course
[ -f /ckad-state/kubeconfig ] && cp /ckad-state/kubeconfig /root/.kube/config
python3 -m http.server 8879 --bind 127.0.0.1 --directory /srv/charts >/dev/null 2>&1 &
exec sleep infinity
