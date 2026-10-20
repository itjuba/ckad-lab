# Lesson 32: Changing a running Deployment

Curriculum: "Understand Deployments and how to perform rolling updates" (Application
Deployment, 20%) and "Define resource requirements" (Application Environment,
Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. The situation

An app already runs as a Deployment. Now it needs settings, resource limits and labels,
without deleting it. You change the Deployment, and Kubernetes rolls out new Pods with
the changes. You never edit the Pods themselves: they're replaced anyway.

------------------------------------------------------------------------------------------
## 2. Where things live in a Deployment

The most important distinction: the Deployment's own metadata vs the Pod TEMPLATE.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:                         # <- the DEPLOYMENT object itself
  name: api
  labels: {app: api}              #    labels/annotations here describe the Deployment
  annotations: {owner: team-x}    #    (k label deploy / k annotate deploy change these)
spec:
  replicas: 3
  selector:
    matchLabels: {app: api}       # can't be changed after creation
  template:
    metadata:                     # <- the Pod TEMPLATE: copied into every new Pod
      labels: {app: api}          #    Pod labels go HERE
    spec:
      containers:
      - name: nginx
        image: nginx:1.29-alpine
        env:                      #    environment variables
        - {name: MODE, value: "production"}
        resources:                #    requests and limits
          requests: {cpu: 50m, memory: 64Mi}
          limits: {memory: 128Mi}
```

Any change under `spec.template` starts a rolling update. Changes to the Deployment's own
metadata (labels, annotations) don't.

------------------------------------------------------------------------------------------
## 3. kubectl set: quick changes without YAML

```bash
# environment variables (several at once)
k set env deploy/api -n demo MODE=production LOG_LEVEL=info
k set env deploy/api -n demo --list               # show the current env
k set env deploy/api -n demo MODE-                # remove one (trailing dash)

# requests and limits
k set resources deploy/api -n demo --requests=cpu=50m,memory=64Mi --limits=memory=128Mi
#   add -c <container> when the Pod has several containers

# image
k set image deploy/api -n demo nginx=nginx:1.29-alpine
```

------------------------------------------------------------------------------------------
## 4. Labels and annotations

  Labels       for selecting and grouping (Services, selectors, -l)
  Annotations  for information (owner, links, notes); nothing selects on them

```bash
k label deploy api -n demo tier=web          # labels the DEPLOYMENT object
k annotate deploy api -n demo owner=team-x   # annotates the DEPLOYMENT object
k label deploy api -n demo tier-             # remove a label (trailing dash)
```

There's no command that adds a label to the Pod TEMPLATE. Edit the Deployment:

```bash
k edit deploy api -n demo       # add it under spec.template.metadata.labels
```

`k label pod ...` on a running Pod is lost as soon as that Pod is replaced.

------------------------------------------------------------------------------------------
## 5. Requests and limits in two sentences

  requests  what the scheduler reserves for the container (it decides on which node
            it fits). cpu in millicores (50m = 5% of a core), memory in Mi/Gi
  limits    the maximum. Over the memory limit the container is killed (OOMKilled);
            over the CPU limit it's slowed down

------------------------------------------------------------------------------------------
## 6. Checking the result

```bash
k rollout status deploy/api -n demo              # wait for the new Pods
k get pod -n demo --show-labels                  # Pod labels on the NEW Pods
k describe deploy api -n demo | grep -i -A3 -e environment -e limits -e requests
k get deploy api -n demo -o yaml | less          # everything, search with /
```

------------------------------------------------------------------------------------------
## 7. How this applies to question 32

  Task 1  One `k set env` with both variables.
  Task 2  One `k set resources` with requests and the memory limit.
  Task 3  `k edit` the Deployment: the label belongs in the Pod template, not the
          Deployment's metadata, and don't touch the selector.
  Task 4  `k annotate` the Deployment itself.
  Finally wait for the rollout and check that all 3 new Pods carry the new label.

------------------------------------------------------------------------------------------
## 8. Common mistakes

  - `k label deploy ... version=v2` for task 3: that labels the Deployment, not its Pods
  - Adding the label to `spec.selector` too: the selector can't be changed (the API
    rejects it), and it isn't needed
  - Putting a memory limit under requests (or the other way round)
  - Annotating the Pods instead of the Deployment for task 4
  - Not waiting for the rollout before checking

------------------------------------------------------------------------------------------
## 9. Docs (kubernetes.io)

  Search "Deployments"                                   updating a Deployment
  Search "kubectl set env" / "kubectl set resources"     command references
  Search "Resource Management for Pods and Containers"   requests and limits
  Search "Labels and Selectors" / "Annotations"          the difference

See also: ckad explain 31 (Deployment basics), ckad explain 42 (requests, limits, QoS)

Now try it: ckad q 32
