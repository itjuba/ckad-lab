# Lesson 26: Blue/green deployments

Curriculum: "Use Kubernetes primitives to implement common deployment strategies (e.g.
blue/green or canary)" (Application Deployment, 20%).

------------------------------------------------------------------------------------------
## 1. The problem

A normal rolling update replaces Pods a few at a time. For a while, old and new versions
serve traffic together, and rolling back takes another rollout.

Sometimes you want a clean cut instead: start the new version completely, test it, then
move ALL traffic at once, and be able to move it back instantly. That's blue/green:

  blue      the version serving users now
  green     the new version, started next to it, receiving no traffic yet
  switch    one change that points all traffic from blue to green
  rollback  point it back to blue (still running, or quickly scaled up again)

Kubernetes has no "BlueGreen" object. You build it from two primitives you already know:
two Deployments and one Service.

------------------------------------------------------------------------------------------
## 2. How a Service picks its Pods

A Service sends traffic to every READY Pod whose labels match its selector. That's the
lever for blue/green.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  selector:
    app: shop
    version: blue          # <- the switch: change this to green
  ports:
  - port: 80
    targetPort: 80
```

Both Deployments carry `app: shop` in their Pod template labels, but a different
`version` label:

  Deployment shop-blue    Pod labels  app=shop, version=blue
  Deployment shop-green   Pod labels  app=shop, version=green

Because the Service selects `version: blue`, green Pods get no traffic, even while
they're running. Changing the selector to `version: green` moves everything at once.

------------------------------------------------------------------------------------------
## 3. Building the green Deployment

```bash
k create deploy shop-green -n demo --image=<image> --replicas=3 $do > green.yaml
vim green.yaml
```

`kubectl create deploy` labels Pods `app=<deployment name>` only. Change the selector AND
the template labels to the labels you need (they must match each other), and add
container args if the task asks for them:

```yaml
spec:
  selector:
    matchLabels:
      app: shop
      version: green
  template:
    metadata:
      labels:
        app: shop
        version: green
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=green"]     # args = parameters for the image's own program
```

Wait until green is fully ready BEFORE switching:

```bash
k rollout status deploy/shop-green -n demo
```

------------------------------------------------------------------------------------------
## 4. The switch, and checking it

```bash
k edit svc shop -n demo                       # change version: blue -> version: green
# or as one command:
k patch svc shop -n demo -p '{"spec":{"selector":{"app":"shop","version":"green"}}}'

k describe svc shop -n demo | grep -i -e selector -e endpoints   # green Pod IPs only
k get pod -n demo -o wide --show-labels                          # compare the IPs
```

Testing from inside the cluster with a temporary Pod (`--rm` deletes it afterwards):

```bash
k run tmp -n demo --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://shop
```

`kubectl run --rm -i` may add a line like `pod "tmp" deleted` to the output. Check the
file and remove that line if needed.

Keeping blue for a rollback, without it using resources:

```bash
k scale deploy shop-blue -n demo --replicas=0     # Deployment stays, Pods go away
```

------------------------------------------------------------------------------------------
## 5. Blue/green vs canary

  Blue/green   two versions, the Service points at ONE of them, the switch is instant
  Canary       both versions behind the same selector at the SAME time; the replica
               counts decide the share (1 of 4 Pods = about 25% of traffic)

------------------------------------------------------------------------------------------
## 6. How this applies to question 26

  Task 1  Generate `checkout-green` with $do, set both labels in the selector and the
          template, add the container arg, apply, and wait for the rollout.
  Task 2  Only after 3/3 are ready: change the Service's selector so it matches green
          and no longer matches blue. Check the endpoints.
  Task 3  A temporary Pod in `tucana`, wget the Service name, output into the file.
  Task 4  Scale blue to 0. Don't delete it.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Template labels that don't match the selector: the Deployment is rejected
  - Changing the selector to only `app: checkout`: that sends traffic to blue AND green
  - Switching before green is ready: users hit Pods that can't answer yet
  - Deleting blue instead of scaling it to 0: no quick rollback
  - Running the temporary Pod in another namespace: the short name `checkout` then
    doesn't resolve (use the namespace the Service is in)

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Deployments"                 Deployment YAML, scaling, rollout status
  Search "Service"                     selectors and how endpoints are chosen
  Search "Labels and Selectors"        label syntax and matching

See also: ckad explain 22 (canary), ckad explain 8 (rolling updates and rollbacks)

Now try it: ckad q 26
