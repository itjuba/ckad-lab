# Lesson 27: Troubleshooting Services, and NodePort

Curriculum: "Provide and troubleshoot access to applications via services" (Services and
Networking, 20%).

------------------------------------------------------------------------------------------
## 1. What a Service does

Pods come and go, and every new Pod gets a new IP. A Service gives a group of Pods one
stable name and IP, and spreads traffic across them.

  Which Pods?    the Service's `selector` matches Pod LABELS
  Which port?    `port` (on the Service) forwards to `targetPort` (on the Pods)
  The result     a list of ready Pod IPs, called the Service's endpoints

If the selector matches no Pod, the Service exists but has no endpoints, and every
request fails. This is the most common Service bug.

------------------------------------------------------------------------------------------
## 2. Service types

  ClusterIP   (default) reachable only inside the cluster, by name or ClusterIP
  NodePort    ClusterIP + a port opened on EVERY node (30000-32767), reachable from
              outside the cluster at <node-address>:<nodePort>
  LoadBalancer  NodePort + an external load balancer from the cloud provider

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: NodePort
  selector:
    app: web                 # must match the Pods' labels exactly
  ports:
  - port: 80                 # the Service's own port (inside the cluster)
    targetPort: 8080         # the container's port: a number, or a port NAME
    nodePort: 30080          # the port opened on every node; omit it for a random one
```

`targetPort` can be a name, such as `http`. It then refers to a port with that name in
the container spec (`ports: - containerPort: 8080, name: http`).

------------------------------------------------------------------------------------------
## 3. Creating Services

```bash
k expose deploy web -n demo --port=80 --target-port=8080               # ClusterIP
k expose deploy web -n demo --port=80 --target-port=8080 --type=NodePort
k create service nodeport web --tcp=80:8080 --node-port=30080 $do      # can set nodePort
```

`k expose` copies the selector from the Deployment, so it's always right. A Service
written by hand is where selector typos happen. `k expose` can't set a fixed nodePort;
edit the Service afterwards, or use `k create service nodeport --node-port`.

Note: `k create service` sets the selector to `app=<service name>`. Check it matches!

------------------------------------------------------------------------------------------
## 4. Debugging a Service: the order to check

```bash
# 1. Does it have endpoints?
k describe svc web -n demo           # "Endpoints:" line empty = selector matches nothing
k get endpointslices -n demo -l kubernetes.io/service-name=web

# 2. Selector vs Pod labels
k describe svc web -n demo | grep -i selector
k get pod -n demo --show-labels

# 3. targetPort vs the port the container really listens on
k describe svc web -n demo | grep -i targetport
k describe pod <pod> -n demo | grep -i port
```

`k get endpoints` still works but prints a deprecation warning in v1.33+ (Endpoints were
replaced by EndpointSlices). The warning is harmless.

Fixing it:
  - Wrong selector -> `k edit svc` and correct the selector (or the Pod template labels,
    if the task allows changing the Deployment)
  - Wrong targetPort -> `k edit svc` and set the container's real port (or its name)

Every Service selector key must match: a selector with two labels needs Pods carrying
BOTH labels.

------------------------------------------------------------------------------------------
## 5. Changing the type to NodePort

```bash
k edit svc web -n demo
```

Change `type: ClusterIP` to `type: NodePort`, and add `nodePort:` under the port when a
specific number is required. Then test from outside the cluster:

```bash
curl -s http://<node>:30080          # in this lab: http://k3d-ckad-server-0:<nodePort>
k get svc web -n demo                # PORT(S) column shows 80:30080/TCP
```

------------------------------------------------------------------------------------------
## 6. How this applies to question 27

  Task 1  Start with the endpoints (empty?), then compare the Service selector with the
          Pods' labels. Fix the Service, not the Deployment. Describe the cause in one
          line in the file (what didn't match what).
  Task 2  Edit the same Service: change its type and set the required nodePort.
  Task 3  curl the node port on k3d-ckad-server-0 from the terminal and save the output.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Editing the Deployment's labels when the task says not to change it
  - Fixing only one of two selector labels: every selector key must match
  - Mixing up port / targetPort / nodePort: the node port is the one you curl from
    outside; port is for traffic inside the cluster
  - nodePort outside 30000-32767: the API server rejects it
  - Forgetting to check the endpoints after the fix

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Service"                           types, ports, selectors, NodePort example
  Search "Debug Services"                    a step-by-step checklist
  Search "Connecting Applications with Services"   hands-on walkthrough

See also: ckad explain 10 (Services and DNS), ckad explain 39 (named ports)

Now try it: ckad q 27
