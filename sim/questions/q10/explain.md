# Lesson 10: Services and cluster DNS

Curriculum: "Provide and troubleshoot access to applications via services"
(Services and Networking, 20%).

------------------------------------------------------------------------------------------
## 1. The problem Services solve

Pods come and go, and every new Pod gets a new IP. Other apps can't keep track of that.
A Service gives a group of Pods ONE stable address:

  - a fixed virtual IP (the ClusterIP) and a DNS name
  - load balancing across all matching, Ready Pods
  - Pods are matched by LABEL SELECTOR, not by name

  client --> Service (selector app=api) --> Pod app=api, Pod app=api, Pod app=api

------------------------------------------------------------------------------------------
## 2. The Service manifest

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: phoenix
spec:
  type: ClusterIP           # default: reachable only inside the cluster
  selector:
    app: api                # send traffic to Pods with this label
  ports:
  - name: web               # optional name for this Service port
    port: 3333              # the port clients connect to ON THE SERVICE
    targetPort: http        # the port on the POD: a number (80) or a port NAME (http)
```

The three port words:

  port         where the Service listens (clients use this)
  targetPort   where the container listens (defaults to `port` if omitted)
  nodePort     only for type NodePort: a port 30000-32767 opened on every node (lesson 27)

A named targetPort (`http`) follows the container's `ports[].name`, so the Service keeps
working if the container's port number changes.

Service types: ClusterIP (internal, most common), NodePort (also on every node's IP),
LoadBalancer (a cloud load balancer). `clusterIP: None` makes a "headless" Service.

------------------------------------------------------------------------------------------
## 3. Creating Services

```bash
# expose copies the selector from the Pod/Deployment: the safest way
k expose pod api -n phoenix --name=api-svc --port=3333 --target-port=80
k expose deploy api -n phoenix --port=80 --type=NodePort
k expose pod api -n phoenix --name=api-svc --port=3333 $do > svc.yaml   # then edit

# create service: selector is set to app=<service-name>, which may NOT match your Pods
k create service clusterip api-svc --tcp=3333:80
```

------------------------------------------------------------------------------------------
## 4. Is the Service connected? Endpoints

The Pods a Service currently sends traffic to are its endpoints:

```bash
k get svc -n phoenix
k describe svc api-svc -n phoenix        # Selector, Port, TargetPort, Endpoints: <IPs>
k get endpointslices -n phoenix          # the same information as objects
```

`Endpoints: <none>` means the selector matches no Ready Pod: compare the selector with
`k get pods --show-labels`. (`k get endpoints` still works but prints a deprecation
warning in v1.37; EndpointSlices replace it.)

------------------------------------------------------------------------------------------
## 5. DNS names

Every Service gets a DNS name:

  <service>.<namespace>.svc.cluster.local       full name, works from anywhere
  <service>.<namespace>                         short form, works from anywhere
  <service>                                     only from the SAME namespace

------------------------------------------------------------------------------------------
## 6. Testing from inside the cluster

The terminal isn't inside the cluster network, so test from a temporary Pod:

```bash
k run tmp -n default --image=busybox:1.37 --restart=Never --rm -i \
  -- wget -qO- http://api-svc.phoenix.svc.cluster.local:3333
k run tmp -n default --image=busybox:1.37 --restart=Never --rm -i \
  -- nslookup api-svc.phoenix.svc.cluster.local
```

`--rm -i` attaches to the Pod and deletes it when the command ends; `--restart=Never`
stops the Pod from being restarted after the command finishes. kubectl may append
`pod "tmp" deleted` to the output: remove that line if you saved the output to a file.
The app's side of the request shows up in its logs (`k logs <pod>`).

------------------------------------------------------------------------------------------
## 7. How this applies to question 10

  Task 1  A Pod with a label and a NAMED container port (kubectl run can't name ports:
          generate YAML and edit).
  Task 2  A ClusterIP Service on the given port whose targetPort is the port NAME.
          `expose` writes a number by default: edit it. Check that Endpoints shows the
          Pod's IP.
  Task 3  A temporary Pod in `default` that requests the full DNS name and port; save
          only the response body.
  Task 4  The request appears in the nginx Pod's logs: save that line.
  Task 5  Make sure the temporary Pod no longer exists in `default`.

------------------------------------------------------------------------------------------
## 8. Common mistakes

  - Selector doesn't match the Pod labels: Endpoints <none>
  - targetPort left as a number when the task asks for the port name
  - Using only `<service>` from another namespace: DNS can't find it
  - Leaving the temporary Pod behind, or the 'pod "tmp" deleted' line in the file
  - Confusing port (Service side) with targetPort (container side)

------------------------------------------------------------------------------------------
## 9. Docs (kubernetes.io)

  Search "Service"                       manifest, ports, types
  Search "DNS for Services and Pods"     DNS name formats
  Search "Debug Services"                step-by-step troubleshooting

See also: ckad explain 27 (debugging a Service, NodePort), ckad explain 39 (two ports),
ckad explain 18 (Ingress)

Now try it: ckad q 10
