# Lesson 40: Pods stuck in Pending: scheduling problems

Curriculum: "Debugging in Kubernetes" (Application Observability and Maintenance, 15%),
with "Define resource requirements" (Application Environment, Configuration and
Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem

`k get pod` shows STATUS Pending and NODE <none>, forever. Nothing in the logs, because the
container never started. What's going on?

Pending + no node = the SCHEDULER hasn't found a node for the Pod. The scheduler is the
part of Kubernetes that picks a node for every new Pod. It only chooses nodes that:

  - have the labels the Pod asks for (nodeSelector / node affinity)
  - don't have taints the Pod doesn't tolerate
  - still have enough free CPU and memory for the Pod's REQUESTS

If no node qualifies, the Pod waits in Pending and the scheduler records why.

------------------------------------------------------------------------------------------
## 2. Where to read the reason

```bash
k get pod -n <ns> -o wide              # STATUS Pending, NODE <none>
k describe pod <pod-name> -n <ns>      # Events at the bottom: Warning FailedScheduling
k get events -n <ns>                   # the same events for the whole namespace
k get events -n <ns> | grep <pod-name>
```

Typical messages:

    0/2 nodes are available: 2 node(s) didn't match Pod's node affinity/selector.
    0/2 nodes are available: 2 Insufficient cpu.
    0/2 nodes are available: 1 node(s) had untolerated taint {...}

Two v1.37 details:

  - `describe` only prints Events when you describe ONE object by name. With `-l` or
    several Pods, use `--show-events=true` or `k get events`.
  - Events expire after about an hour. The latest scheduling message is also stored in
    the Pod's status: `k get pod <pod> -n <ns> -o yaml | grep -B6 PodScheduled`.

Don't confuse it with problems AFTER scheduling (a node is set):
ContainerCreating (volume/secret missing), ImagePullBackOff (image), CrashLoopBackOff (app).

------------------------------------------------------------------------------------------
## 3. Cause 1: nodeSelector and node labels

A Pod can demand nodes with a certain label:

```yaml
spec:
  nodeSelector:
    gpu: "true"              # only nodes labelled gpu=true qualify
  containers:
  - name: trainer
    image: busybox:1.37
```

Node labels are ordinary labels on Node objects:

```bash
k get nodes --show-labels                  # all labels of all nodes (long)
k get nodes -L gpu                         # adds a GPU column with that label's value
k describe deploy <name> -n <ns> | grep -i -A1 node-selectors   # what the Pods ask for
k label node <node-name> gpu=true          # add a label
k label node <node-name> gpu-              # remove it (key followed by -)
```

As soon as a matching node exists, the scheduler places the Pending Pods by itself.
There's no need to restart them.

------------------------------------------------------------------------------------------
## 4. Cause 2: requests bigger than any node

`resources.requests` is what the scheduler RESERVES on a node. If no node has that much
unreserved CPU or memory, the Pod can't be placed:

```yaml
    resources:
      requests:
        cpu: "8"            # 8 whole CPUs
        memory: 256Mi
```

CPU units: `1` = one CPU core, `500m` = half a core, `100m` = a tenth. "64" is 64 cores.

```bash
k describe node <node-name> | grep -A8 Allocatable     # what a node can offer
k describe node <node-name> | grep -A8 "Allocated resources"   # what's already reserved
```

Most of a running Pod's spec can't be changed (including its requests, with normal
edits). To change it, recreate the Pod:

```bash
k get pod <pod> -n <ns> -o yaml > pod.yaml
vim pod.yaml                         # change the request; you can delete the status: part
k replace --force -f pod.yaml        # deletes the old Pod and creates the new one
```

------------------------------------------------------------------------------------------
## 5. How this applies to question 40

  Task 1  Describe ONE of the Deployment's Pods by name and find the FailedScheduling
          message. Save that message (grep for the reason word).
  Task 2  Find out which label the Pods ask for (the Deployment's node selector), then
          give exactly that label to the named node. Don't touch the Deployment. Then
          check `-o wide`: both Pods should be Running on that node.
  Task 3  Same as task 1 for the batch Pod: a different message.
  Task 4  Recreate the Pod with the same name and image and the smaller CPU request
          (`-o yaml` + vim + `replace --force`, or a fresh `k run ... $do`).

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - `k describe pod -l app=...`: no Events with several Pods in v1.37
  - Labelling the wrong node, or with a slightly different key or value: it must match the
    nodeSelector exactly
  - Editing the Deployment's nodeSelector when the task says to fix the node
  - Trying `k edit pod` to change requests: the change is rejected, recreate the Pod
  - Mixing up `100m` (a tenth of a CPU) and `100` (100 CPUs)
  - Reading logs of a Pending Pod: there are none, the container never started

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Assigning Pods to Nodes"            nodeSelector, node affinity
  Search "Assign Pods to Nodes" (task page)   labelling a node, step by step
  Search "Resource Management for Pods and Containers"   requests, CPU units
  Search "Debug Pods"                         Pending, waiting, crashing Pods

See also: ckad explain 42 (requests and limits), ckad explain 24 (taints and tolerations)

Now try it: ckad q 40
