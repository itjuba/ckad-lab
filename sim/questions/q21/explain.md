# Lesson 21: Requests, limits, ResourceQuotas and LimitRanges

Curriculum: "Understand requests, limits, quotas" and "Define resource requirements"
(Application Environment, Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. Requests and limits

Each container can declare how much CPU and memory it needs:

```yaml
    resources:
      requests:            # what the container is GUARANTEED
        cpu: 100m          # 100 millicores = 0.1 CPU core
        memory: 64Mi       # mebibytes
      limits:              # the MAXIMUM it may use
        cpu: 200m
        memory: 128Mi
```

  requests   used by the scheduler: a Pod only lands on a node with that much free
  limits     enforced at runtime: too much CPU = slowed down (throttled);
             too much memory = the container is killed (OOMKilled)

Units: cpu `1` = one core, `500m` = half a core. memory `Mi`/`Gi` (powers of 2).

The quick way to set them on a Deployment (triggers a rollout):

```bash
k set resources deploy web -n demo \
  --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
```

------------------------------------------------------------------------------------------
## 2. ResourceQuota: a budget for a namespace

A ResourceQuota caps the TOTAL a namespace may use:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: demo
spec:
  hard:
    pods: "5"                # at most 5 Pods
    requests.cpu: "1"        # all requests together <= 1 core
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
```

```bash
k create quota team-quota -n demo --hard=pods=5,requests.cpu=1,limits.memory=2Gi
k describe quota -n demo           # Used vs Hard for each resource
```

The important side effect: once a quota covers cpu or memory, EVERY new Pod in that
namespace must declare those requests/limits. A Pod without them is rejected.

------------------------------------------------------------------------------------------
## 3. Where the error shows up

A Deployment doesn't create Pods itself. It creates a ReplicaSet, and the ReplicaSet
creates the Pods. So when the quota rejects Pods, the error is on the REPLICASET:

  Deployment (looks fine, 0/3 ready) --> ReplicaSet (FailedCreate events) --> no Pods

```bash
k get deploy,rs,pod -n demo                  # rs: DESIRED 3, CURRENT 0
k describe rs web-<hash> -n demo             # Events: ... forbidden: failed quota ...
k get events -n demo | grep -i quota         # the same message from the event list
```

Note: kubectl v1.37 shows Events only when you describe ONE object by name. With `-l`
or several objects they're hidden; use the name, `--show-events=true`, or `k get events`.

------------------------------------------------------------------------------------------
## 4. LimitRange: defaults (and min/max) per container

A LimitRange fills in requests/limits for containers that don't set them, so Pods without
a `resources:` block still pass the quota:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-defaults
  namespace: demo
spec:
  limits:
  - type: Container
    defaultRequest:          # becomes the REQUESTS of containers that set none
      cpu: 50m
      memory: 32Mi
    default:                 # becomes the LIMITS of containers that set none
      cpu: 100m
      memory: 64Mi
    # max: / min:            # optional: reject containers outside this range
```

The names are confusing: `default` = limits, `defaultRequest` = requests.

A LimitRange is applied when a Pod is CREATED. It never changes Pods that already run.
There's no `kubectl create limitrange`; copy it from the docs.

Checking that a new Pod got the defaults:

```bash
k run probe -n demo --image=nginx:1.29-alpine        # no resources given
k describe pod probe -n demo | grep -A5 Limits       # Limits and Requests filled in
```

------------------------------------------------------------------------------------------
## 5. How this applies to question 21

  Task 1  Find the ReplicaSet of the Deployment, describe it BY NAME, and read the
          FailedCreate event (or grep the events). Write that message into the file.
  Task 2  `k set resources` with the four values from the task, then watch the rollout:
          the quota is satisfied, so the Pods appear.
  Task 3  A LimitRange from the docs with the given defaultRequest and default values.
  Task 4  Create the Pod with `k run` and NO resources. Describe it to confirm the values
          match the LimitRange defaults.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Looking for the error on the Deployment or Pods instead of the ReplicaSet
  - Describing with `-l` and seeing no Events (v1.37)
  - Swapping `default` and `defaultRequest`
  - Giving the test Pod resources: then the LimitRange defaults don't apply
  - Creating the test Pod BEFORE the LimitRange exists
  - Mixing units: `100` CPU is 100 cores, not 100m

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Resource Management for Pods and Containers"   requests, limits, units
  Search "Resource Quotas"                               what quotas can cap
  Search "Limit Ranges"                                  LimitRange fields
  Search "Configure Default Memory Requests and Limits for a Namespace"

See also: ckad explain 42 (QoS classes), ckad explain 25 (kubectl top, OOMKilled)

Now try it: ckad q 21
