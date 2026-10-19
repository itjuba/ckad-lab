# Solution 6

## Part 1

```bash
k -n hydra run heartbeat --image=nginx:1.29-alpine $do > 6.yaml
vim 6.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: heartbeat
  namespace: hydra
spec:
  containers:
  - name: heartbeat
    image: nginx:1.29-alpine
    readinessProbe:              # added
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
    livenessProbe:               # added
      tcpSocket:
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 20
      failureThreshold: 3
```

```bash
k apply -f 6.yaml
k -n hydra get pod heartbeat -w        # READY 0/1 -> 1/1 after ~5-15s
```

## Part 2

```bash
k -n hydra get pods                    # RESTARTS keeps climbing, READY 0/1
k -n hydra describe pod -l app=hydra-api | grep -A3 -E 'Liveness|Readiness|Unhealthy'
#   Liveness probe failed: ... dial tcp <ip>:8080: connect: connection refused
k -n hydra edit deploy hydra-api       # both probes: port: 8080 -> port: 80 (or: port: http)
k -n hydra rollout status deploy hydra-api
```

Remember:
- A failing **liveness** probe restarts the container. A failing **readiness**
  probe only takes the Pod out of Service endpoints.
- The Events at the bottom of `describe pod` usually tell you exactly which probe
  failed and why.
