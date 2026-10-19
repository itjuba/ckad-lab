# Native sidecar for log shipping

Namespace: `auriga`

The Deployment `auriga-ledger` in Namespace `auriga` writes its log to a file,
`/var/log/ledger/ledger.log`, on a volume, so `kubectl logs` shows nothing. Team Auriga
wants the log on stdout without changing the application container.

1. Add a sidecar container named `log-shipper` to Deployment `auriga-ledger`:
   - image `busybox:1.37`
   - command `tail -F /var/log/ledger/ledger.log`
   - mounts the existing volume `logs` at `/var/log/ledger`
   - it must be a **native sidecar**, meaning Kubernetes starts it before the
     app container and keeps it running for the whole life of the Pod

2. After the rollout, write some of the `log-shipper` container's log
   output (via `kubectl logs`) into `/opt/course/16/ledger.log`.
