# Lesson 18: Ingress, and debugging a Service's targetPort

Curriculum: "Use Ingress rules to expose applications" and "Provide and troubleshoot
access to applications via services" (Services and Networking, 20%).

------------------------------------------------------------------------------------------
## 1. Service recap: port vs targetPort

A Service gives a stable name and IP to a group of Pods. Three things must line up:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web            # 1. which Pods: those with this label
  ports:
  - port: 8080          # 2. the port CLIENTS use:  http://web:8080
    targetPort: 80      # 3. the port the CONTAINER listens on
```

  client --> web:8080 (Service port) --> Pod IP:80 (targetPort = containerPort)

Endpoints = the list of Pod IP:targetPort pairs the Service forwards to.

```bash
k describe svc web -n demo    # Selector, Port, TargetPort, Endpoints: 10.42.0.7:80
k get endpointslices -n demo -l kubernetes.io/service-name=web
```

(`k get ep` still works but prints a deprecation warning since v1.33; EndpointSlices
replace Endpoints.)

Two different bugs look similar:
  no endpoints at all        the selector matches no Pods (labels wrong)
  endpoints, but no answer   the selector is right, but targetPort points at a port
                             nothing listens on

Endpoints existing does NOT prove the Service works. Compare the port in the Endpoints
line with the containerPort:

```bash
k get deploy web -n demo -o yaml | grep -A3 ports         # containerPort: 80
k describe svc web -n demo | grep -i -e port -e endpoints  # TargetPort / Endpoints :8080 ?
```

------------------------------------------------------------------------------------------
## 2. Ingress: HTTP routing into the cluster

A Service is reachable inside the cluster. An Ingress routes outside HTTP traffic by
hostname and URL path to Services:

  http://shop.example.local/shop  -->  Service shop:8080
  http://shop.example.local/api   -->  Service api:80

An Ingress is only rules. An ingress CONTROLLER (a proxy running in the cluster) reads
them and does the routing. Which controller handles an Ingress is chosen by its
IngressClass:

```bash
k get ingressclass          # here: traefik (default). On the exam it may be nginx.
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  namespace: demo
spec:
  ingressClassName: traefik          # which controller
  rules:
  - host: shop.example.local         # match the HTTP Host header
    http:
      paths:
      - path: /shop
        pathType: Prefix             # Prefix: /shop, /shop/cart ...  Exact: only /shop
        backend:
          service:
            name: shop               # a Service in the SAME namespace
            port:
              number: 8080           # the SERVICE port, not the container port
```

------------------------------------------------------------------------------------------
## 3. The commands

`k create ingress` builds this for you. `*` at the end of a path means Prefix; no `*`
means Exact:

```bash
k create ingress demo -n demo --class=traefik \
  --rule="shop.example.local/shop*=shop:8080" \
  --rule="shop.example.local/api*=api:80" $do > ing.yaml
cat ing.yaml                                  # check path, pathType, service, port
k apply -f ing.yaml
k describe ingress demo -n demo               # rules and their backends
```

Testing: the Host header must match the rule's host. In this environment the controller
listens on port 80 of the nodes, reachable from the terminal as `k3d-ckad-server-0`:

```bash
curl -s -H 'Host: shop.example.local' http://k3d-ckad-server-0/shop
```

A 404 right after creating it: the controller may need a few seconds; retry.

Testing a Service from inside the cluster with a throwaway Pod:

```bash
k run tmp -n demo --rm -it --restart=Never --image=busybox:1.37 -- wget -qO- http://api
```

------------------------------------------------------------------------------------------
## 4. How this applies to question 18

  Task 1  `k get svc,endpointslices -n antares`, then compare the api Service's targetPort
          with the port the api container really listens on (`k get deploy ... -o yaml`).
          Fix the SERVICE (`k edit svc`), not the Deployment. Verify with a temporary Pod.
  Task 2  One `k create ingress` with two `--rule`s. Use each Service's own port (look it
          up with `k get svc -n antares`). Check the generated YAML before applying.
  Task 3  Run the given curl and redirect its output into the file. The api backend
          answers /api with JSON; that's expected.

------------------------------------------------------------------------------------------
## 5. Common mistakes

  - Using the container port in the Ingress backend instead of the Service port
  - Forgetting `*` in `--rule` paths: you get pathType Exact instead of Prefix
  - Missing or wrong `--class`
  - Curl without the Host header: no rule matches, you get a 404
  - "Fixing" the Deployment's port when the task says to fix the Service
  - Trusting "it has endpoints" without checking the targetPort

------------------------------------------------------------------------------------------
## 6. Docs (kubernetes.io)

  Search "Ingress"          rules, pathType, IngressClass, examples
  Search "Service"          port, targetPort, named ports
  Search "Debug Services"   step-by-step Service troubleshooting

See also: ckad explain 10 (Service + DNS), ckad explain 27 (selector bug + NodePort)

Now try it: ckad q 18
