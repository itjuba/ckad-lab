# Lesson 39: Services with several named ports, ClusterIP and NodePort

Curriculum: "Provide and troubleshoot access to applications via services" (Services and
Networking, 20%).

------------------------------------------------------------------------------------------
## 1. The problem

Pods come and go, and every new Pod gets a new IP. Clients need ONE stable address that
always reaches the current Pods. That's a Service: a stable name and IP that load-balances
to all Pods matching its selector.

Some apps listen on more than one port, for example a website on 80 and metrics on 9100.
One Service can expose both.

------------------------------------------------------------------------------------------
## 2. The four numbers and names of a Service port

```yaml
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  type: ClusterIP               # ClusterIP (default, inside the cluster) or NodePort
  selector:
    app: shop                   # sends traffic to Pods with this LABEL
  ports:
  - name: web                   # required as soon as there is more than one port
    port: 80                    # the port clients use: http://shop:80
    targetPort: http            # the container port: a number, or the port's NAME
  - name: stats
    port: 9100
    targetPort: stats
```

Named container ports are defined in the Pod template:

```yaml
      containers:
      - name: web
        image: nginx:1.29-alpine
        ports:
        - containerPort: 80
          name: http            # targetPort: http refers to this name
```

Why names? If the container port number changes later, the Service keeps working.

------------------------------------------------------------------------------------------
## 3. ClusterIP vs NodePort

  ClusterIP   reachable only inside the cluster, by name: http://shop:80 (same namespace)
              or http://shop.<namespace>.svc.cluster.local:80 (from anywhere)
  NodePort    a ClusterIP PLUS a port (30000-32767) opened on every node:
              http://<any-node>:<nodePort> works from outside the cluster

```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: http
    nodePort: 30123             # optional: pick it yourself, otherwise random
```

A Service can expose only some of the Pod's ports. A second Service for the same Pods,
with different ports, is common: an internal one and an external one.

------------------------------------------------------------------------------------------
## 4. Commands

```bash
k get pod -n <ns> --show-labels                 # which labels the Pods have

# A) create service: several --tcp ports, selector is ALWAYS app=<service name>
k create svc clusterip shop -n <ns> --tcp=80:80 --tcp=9100:9100 $do > svc.yaml
#    generated port names look like "80-80": rename them in vim

# B) expose: copies the selector from the Deployment, --target-port takes a name
k expose deploy shop -n <ns> --name=shop-ext --type=NodePort --port=80 \
  --target-port=http $do > svc-ext.yaml
#    add nodePort: <number> under the port in vim

k apply -f svc.yaml
k get svc -n <ns>                               # TYPE, CLUSTER-IP, PORT(S): 80:30123/TCP
k get endpoints shop -n <ns>                    # Pod IPs behind it; empty = problem
k describe svc shop -n <ns>                     # selector, ports, target ports, endpoints
```

Testing:

```bash
curl -s http://<node-name>:<nodePort>                       # NodePort, from the terminal
k run tmp -n <ns> --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://shop:9100
```

------------------------------------------------------------------------------------------
## 5. How this applies to question 39

  Task 1  Check the Pod labels. Generate a ClusterIP Service with both ports, then in vim
          give each port the required name and point targetPort at the container port
          NAMES. `k get endpoints` should show both Pods.
  Task 2  A second Service of type NodePort with only the website port, the named
          targetPort, and the fixed nodePort. `k expose deploy` gets the selector right.
  Task 3  curl the node and nodePort from the terminal and redirect the output.
  Task 4  A temporary busybox Pod in the same namespace can use the short Service name.
          Save its output, and leave no temporary Pod behind.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Multi-port Service without a `name` on each port: the API rejects it
  - `k create svc nodeport <name>` sets the selector app=<name>: if the Service name isn't
    the Pods' label, it matches nothing (empty endpoints)
  - targetPort pointing at a name or number the container doesn't use: requests fail.
    Compare with the Ports shown by `k describe pod`
  - Confusing port and targetPort: clients use `port`, the container listens on targetPort
  - nodePort outside 30000-32767, or already used by another Service
  - Testing from a Pod in another namespace with the short name: use the full name there

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Service"                  concept page: "Multi-port Services", "type NodePort",
                                    "Defining a Service" (named targetPort)
  Search "Connecting Applications with Services"
  Search "kubectl expose"           the command reference

See also: ckad explain 10 (Service + DNS), ckad explain 27 (debugging a Service)

Now try it: ckad q 39
