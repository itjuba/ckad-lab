# Lesson 31: Deployment basics: create, scale, update, expose

Curriculum: "Understand Deployments and how to perform rolling updates" (Application
Deployment, 20%).

------------------------------------------------------------------------------------------
## 1. Why Deployments exist

A bare Pod is fragile: if it dies or its node fails, nothing replaces it. A Deployment
keeps a desired number of identical Pods running, replaces failed ones, and changes
versions safely with rolling updates.

The chain of objects:

  Deployment  -> creates and manages ->  ReplicaSet  -> creates ->  Pods
  (what you edit)                        (one per version)         (the running copies)

You only work with the Deployment. Each time its Pod template changes, it creates a new
ReplicaSet for the new version and scales the old one down.

------------------------------------------------------------------------------------------
## 2. The manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 2                     # how many Pods
  selector:
    matchLabels:
      app: web                    # which Pods belong to this Deployment
  template:                       # the Pod template: every Pod is created from this
    metadata:
      labels:
        app: web                  # must match the selector
    spec:
      containers:
      - name: nginx               # kubectl create deploy names it after the image
        image: nginx:1.28-alpine
        ports:
        - containerPort: 80
```

------------------------------------------------------------------------------------------
## 3. The everyday commands

```bash
# create (--port sets containerPort, --replicas the count)
k create deploy web -n demo --image=nginx:1.28-alpine --replicas=2 --port=80

# look at it
k get deploy,rs,pod -n demo
k describe deploy web -n demo

# scale
k scale deploy web -n demo --replicas=4

# change the image: <container name>=<new image>
k set image deploy/web -n demo nginx=nginx:1.29-alpine

# watch the rollout until it's done
k rollout status deploy/web -n demo

# revisions
k rollout history deploy/web -n demo
k rollout history deploy/web -n demo --revision=2    # details of one revision
```

`kubectl create deploy` labels the Pods `app=<deployment name>` and names the container
after the image (`nginx` for nginx:1.28-alpine). `k set image` needs that CONTAINER name.
Check it with `k describe deploy web -n demo | grep -A2 Containers`.

------------------------------------------------------------------------------------------
## 4. Rolling updates and revisions

Changing anything in the Pod template (image, env, labels, resources) starts a rolling
update: new Pods come up, old ones go away a few at a time, and the Deployment gets a new
REVISION. Scaling does NOT create a revision; it doesn't change the template.

`k rollout history` output looks like:

    REVISION  CHANGE-CAUSE
    1         <none>
    2         <none>

------------------------------------------------------------------------------------------
## 5. Exposing a Deployment with a Service

Pods get new IPs whenever they're replaced. A Service gives them one stable name:

```bash
k expose deploy web -n demo --port=8080 --target-port=80
#   --port         the Service's port (what clients call)
#   --target-port  the container's port (where traffic is delivered)
#   --type         ClusterIP (default), NodePort, ...

k get svc web -n demo
k describe svc web -n demo | grep -i endpoints     # one IP per ready Pod
```

`k expose` copies the Deployment's selector, so the Service finds the right Pods.

------------------------------------------------------------------------------------------
## 6. How this applies to question 31

  Task 1  One `k create deploy` with image, replica count and port.
  Task 2  One `k scale`.
  Task 3  `k set image` with the container name, then `k rollout status`.
  Task 4  `k rollout history ... > file`. Two template versions = two revisions.
  Task 5  One `k expose` with the two port flags, then check the endpoints.

Every task has an imperative command here; you don't need any YAML.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - `k set image deploy/web web=...`: the left side is the CONTAINER name, not the
    Deployment's
  - Expecting 3 revisions after create + scale + update: scaling isn't a revision
  - Swapping `--port` and `--target-port` on `k expose`
  - Writing the history before the update finished: wait for `rollout status`
  - Forgetting `-n octans` on one of the commands

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Deployments"                     YAML, scaling, updating, rollout history
  Search "kubectl set image"               syntax reference
  Search "Connecting Applications with Services"   kubectl expose in practice

See also: ckad explain 32 (changing a running Deployment), ckad explain 8 (rollbacks)

Now try it: ckad q 31
