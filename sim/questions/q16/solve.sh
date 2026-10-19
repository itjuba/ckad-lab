#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl patch deploy auriga-ledger -n auriga --type=strategic -p '
spec:
  template:
    spec:
      initContainers:
      - name: log-shipper
        image: busybox:1.37
        restartPolicy: Always
        command: ["tail", "-F", "/var/log/ledger/ledger.log"]
        volumeMounts:
        - name: logs
          mountPath: /var/log/ledger
'
wait_rollout auriga auriga-ledger
sleep 6
kubectl logs -n auriga deploy/auriga-ledger -c log-shipper --tail=20 >/opt/course/16/ledger.log
