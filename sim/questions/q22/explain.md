# Lesson 22: Canary releases with labels and a shared Service

Curriculum: "Use Kubernetes primitives to implement common deployment strategies (e.g.
blue/green or canary)" (Application Deployment, 20%).

------------------------------------------------------------------------------------------
## 1. What a canary release is

A new version might have a bug that tests didn't catch. Instead of switching all users at
once, you send a SMALL share of real traffic to the new version first (the "canary"),
watch it, and only then move everyone over. If it misbehaves, only a few users noticed.

Kubernetes has no "canary" object. You build it from things you already know: two
Deployments, labels, and one Service.

------------------------------------------------------------------------------------------
## 2. The key fact: a Service doesn't care about Deployments

A Service sends traffic to every READY Pod whose labels match its selector, no matter
which Deployment created it:

  Service web   selector: app=web
     |
     +--> Pod (app=web, version=v1)   from Deployment web-v1
     +--> Pod (app=web, version=v1)   from Deployment web-v1
     +--> Pod (app=web, version=v1)   from Deployment web-v1
     +--> Pod (app=web, version=v2)   from Deployment web-v2   <- the canary

Traffic is spread roughly evenly across those Pods, so the SPLIT IS THE REPLICA RATIO:
3 v1 + 1 v2 = about 25% to v2. 9 v1 + 1 v2 = about 10%.

------------------------------------------------------------------------------------------
## 3. The labels

Every Pod gets:
  - the SHARED label the Service selects       app=web
  - a VERSION label to tell the versions apart  version=v1 / version=v2

Each Deployment's own selector must include the version label:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      version: v2          # unique per Deployment
  template:
    metadata:
      labels:
        app: web           # what the Service selects
        version: v2        # what THIS Deployment selects
    spec:
      containers:
      - name: web
        image: traefik/whoami:v1.11
        args: ["--name=v2"]
```

Why the version in the Deployment's selector? If both Deployments selected only `app=web`,
their selectors would overlap. The docs warn that controllers with overlapping selectors
fight over the same Pods and don't behave correctly.

------------------------------------------------------------------------------------------
## 4. command vs args

`k create deploy web-v2 --image=x -- something` puts `something` into `command`, which
REPLACES the image's entrypoint (the program it runs). For an image whose entrypoint is
the app itself (like whoami), you only want to pass flags, so add `args:` in vim:

  command   replaces the image's ENTRYPOINT (the program)
  args      replaces the image's CMD (the arguments passed to the program)

------------------------------------------------------------------------------------------
## 5. The commands

```bash
k describe svc web -n demo | grep Selector          # what the Service selects
k get pod -n demo --show-labels                     # existing Pods' labels
k create deploy web-v2 -n demo --image=traefik/whoami:v1.11 --replicas=1 $do > v2.yaml
vim v2.yaml                                         # fix labels/selector, add args
k apply -f v2.yaml
k scale deploy web-v1 -n demo --replicas=3          # adjust the ratio
k get endpointslices -n demo -l kubernetes.io/service-name=web   # 4 endpoints?

# send several requests from a temporary Pod in the namespace
k run tmp -n demo --rm -i --restart=Never --image=busybox:1.37 -- \
  sh -c 'for i in $(seq 10); do wget -qO- http://web; done' | grep '^Name:'
```

Finishing the canary: scale v2 up and v1 down step by step. Rolling back: scale v2 to 0.
The Service never changes in either case.

Blue/green is different: two full versions exist, and you switch the Service's selector
from one to the other in a single step (lesson 26).

------------------------------------------------------------------------------------------
## 6. How this applies to question 22

  Task 1  Check the Service's selector and the v1 Pods' labels first. Generate the v2
          Deployment with $do, then fix its labels and selector (shared label + version
          label) and add the argument with `args`. Do NOT edit the Service.
  Task 2  Count: 4 Pods total, 25% v2. Scale v1 accordingly.
  Task 3  A loop of 20 requests from a temporary Pod in `castor`, keep only the `Name:`
          lines, redirect into the file. Both versions should appear.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Leaving the generated label `app: castor-v2`: the Service never matches the new Pods
  - Both Deployments with the same selector: they fight over each other's Pods
  - Changing the Service selector (that's blue/green, and the task forbids it)
  - Passing `--name=v2` after `--` in `k create deploy`: it becomes the command and the
    container fails to start
  - Forgetting to scale v1 down: 4 + 1 = 5 Pods, 20% instead of 25%

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Managing Workloads"        section "Canary deployments"
  Search "Labels and Selectors"      how selectors match
  Search "Define a Command and Arguments for a Container"   command vs args

See also: ckad explain 26 (blue/green switch), ckad explain 8 (rolling updates)

Now try it: ckad q 22
