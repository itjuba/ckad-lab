# Solution 10

```bash
k run phoenix-api -n phoenix --image=nginx:1.29-alpine -l app=phoenix-api --port=80 $do > 10-pod.yaml
vim 10-pod.yaml          # add  name: http  under the containerPort
k apply -f 10-pod.yaml

# expose writes targetPort: 80, so edit it to the port name
k expose pod phoenix-api -n phoenix --name=phoenix-api-svc --port=3333 $do > 10-svc.yaml
vim 10-svc.yaml          # targetPort: http
k apply -f 10-svc.yaml
k get svc,endpointslices -n phoenix
```

```yaml
# Pod: container port
    ports:
    - containerPort: 80
      name: http                  # added
# Service
spec:
  type: ClusterIP
  selector:
    app: phoenix-api
  ports:
  - port: 3333
    targetPort: http              # was: 80
```

Test from the `default` namespace. `--rm -i` deletes the temp Pod when it exits:

```bash
k run tmp -n default --image=busybox:1.37 --restart=Never --rm -i \
  -- wget -qO- http://phoenix-api-svc.phoenix.svc.cluster.local:3333 > /opt/course/10/response.html
cat /opt/course/10/response.html          # remove any 'pod "tmp" deleted' line kubectl added

k logs phoenix-api -n phoenix | grep 'GET /' > /opt/course/10/access.log
k get pods -n default                     # No resources found
```

Remember:
- Service DNS names have the form `<service>.<namespace>.svc.cluster.local`. Inside the same namespace, `<service>` alone works. From another namespace you need at least `<service>.<namespace>`.
- A named `targetPort` follows the container's port name, so the Service keeps working if the container port number changes.
