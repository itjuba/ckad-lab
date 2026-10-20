# Lesson 42: Requests, limits and QoS classes

Curriculum: "Define resource requirements" and "Understand requests, limits, quotas"
(Application Environment, Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem

Many Pods share a node's CPU and memory. Without rules, one greedy Pod can starve the
others, and the scheduler has no idea how much room a Pod needs. Two settings per
container fix this:

  requests   what the container is GUARANTEED. The scheduler only places the Pod on a
             node that still has this much unreserved
  limits     the MAXIMUM the container may use

------------------------------------------------------------------------------------------
## 2. How it looks

```yaml
spec:
  containers:
  - name: api
    image: nginx:1.29-alpine
    resources:                 # per CONTAINER, not per Pod
      requests:
        cpu: 250m              # a quarter of a CPU core reserved
        memory: 64Mi           # 64 mebibytes reserved
      limits:
        cpu: 500m              # never more than half a core
        memory: 128Mi          # never more than 128Mi
```

Units:

  cpu      1 = one core,  500m = half a core,  100m = a tenth   (m = milli)
  memory   Mi, Gi = binary (1Mi = 1024 x 1024 bytes),  M, G = decimal. Use Mi/Gi.

What happens at the limit:

  CPU      the container is slowed down (throttled). It keeps running
  memory   the container is killed: OOMKilled, exit code 137, then restarted

------------------------------------------------------------------------------------------
## 3. QoS classes: who gets evicted first

From the requests and limits of all its containers, Kubernetes gives every Pod a
Quality of Service class. When a node runs out of memory, it evicts Pods in this order:
BestEffort first, then Burstable, Guaranteed last.

  Guaranteed   EVERY container has requests = limits, for BOTH cpu and memory
  Burstable    at least one request or limit is set, but not the Guaranteed pattern
  BestEffort   no requests and no limits at all

Two surprises worth knowing:

  - If you set only limits, Kubernetes copies them into requests. Limits alone therefore
    make a Pod Guaranteed.
  - One container without settings in an otherwise Guaranteed Pod makes it Burstable.

Reading it:

```bash
k describe pod <pod> -n <ns> | grep -i qos         # QoS Class:  Burstable
k get pod <pod> -n <ns> -o yaml | grep qosClass    # qosClass: Burstable
```

------------------------------------------------------------------------------------------
## 4. Commands

`kubectl run` has no resource flags, so for a Pod generate YAML and add the block:

```bash
k run api -n <ns> --image=nginx:1.29-alpine $do > pod.yaml
vim pod.yaml                     # add resources: under the container
k apply -f pod.yaml
```

For anything with a Pod template (Deployment, StatefulSet, DaemonSet...) there's a command:

```bash
k set resources deploy api -n <ns> --requests=cpu=100m,memory=64Mi --limits=memory=128Mi
k set resources deploy api -n <ns> -c=api --requests=cpu=100m   # one container (-c)
k rollout status deploy api -n <ns>     # it's a template change: new Pods roll out
k describe deploy api -n <ns> | grep -i -A3 requests
```

A running Pod's resources can't be changed with a normal edit or apply. Recreate the Pod
(`k replace --force -f pod.yaml`), or change its Deployment.

The docs page has a ready resources block to copy: search "resource management for pods".

------------------------------------------------------------------------------------------
## 5. How this applies to question 42

  Task 1  Generate the Pod, add requests and limits with the given values (they differ),
          apply, then read the QoS class Kubernetes assigned and write it to the file.
  Task 2  Same, with requests equal to limits. Predict the class from section 3, then
          confirm it with describe.
  Task 3  The Deployment needs only requests: one `k set resources` command, then wait
          for the rollout.

Write the class exactly as Kubernetes prints it.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - `resources:` at Pod level instead of under the container
  - `memory: 64m` (64 MILLIbytes) instead of `64Mi`
  - Expecting "requests = limits" for CPU only to give Guaranteed: memory must match too
  - Writing the class from memory instead of reading it: describe shows the real one
  - Trying to change a running Pod's resources with `k edit`: recreate it
  - Forgetting that `k set resources` triggers a rollout: check that all replicas updated

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Resource Management for Pods and Containers"   requests, limits, units
  Search "Configure Quality of Service for Pods"         QoS classes with examples
  Search "kubectl set resources"

See also: ckad explain 21 (ResourceQuota and LimitRange), ckad explain 40 (requests too
big to schedule), ckad explain 25 (OOMKilled)

Now try it: ckad q 42
