# Solution 39

`kubectl create service clusterip` takes several `--tcp` ports and sets the selector
`app=<service name>`, which here matches the Pods (`app=pictor-app`). Generate it, then
fix the port names and targets in vim:

```bash
k get pod -n pictor --show-labels                   # app=pictor-app
k create svc clusterip pictor-app -n pictor --tcp=80:80 --tcp=9100:9100 $do > 39.yaml
vim 39.yaml
```

```yaml
spec:
  selector:
    app: pictor-app
  ports:
  - name: http                  # was: 80-80
    port: 80
    targetPort: http            # was: 80
  - name: metrics               # was: 9100-9100
    port: 9100
    targetPort: metrics         # was: 9100
```

```bash
k apply -f 39.yaml
k get endpoints pictor-app -n pictor                # 2 Pod IPs, each with :80 and :9100
```

The NodePort Service: `k expose` copies the selector from the Deployment.

```bash
k expose deploy pictor-app -n pictor --name=pictor-app-ext --type=NodePort --port=80 --target-port=http $do > 39-ext.yaml
vim 39-ext.yaml                                     # add nodePort: 30781 under the port
k apply -f 39-ext.yaml

curl -s http://k3d-ckad-server-0:30781 > /opt/course/39/nodeport.html

k run tmp -n pictor --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://pictor-app:9100 > /opt/course/39/metrics.txt
cat /opt/course/39/metrics.txt                      # Hostname: pictor-app-...
```

Remember:
- A Service with more than one port must give every port a `name`.
- `targetPort: http` points at the container port **named** `http`. If the container port
  number ever changes, the Service still works.
- `k create svc nodeport NAME` sets the selector `app=NAME`, which would be
  `app=pictor-app-ext` here and match nothing. `k expose deploy` avoids that.
