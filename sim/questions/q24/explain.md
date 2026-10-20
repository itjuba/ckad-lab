# Lesson 24: DaemonSets, init containers, tolerations and the Downward API

Curriculum: "Choose and use the right workload resource (Deployment, DaemonSet, CronJob,
etc.)" and "Understand multi-container Pod design patterns (e.g. sidecar, init and
others)" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. DaemonSet: one Pod on every node

A Deployment runs N copies somewhere in the cluster. A DaemonSet runs exactly ONE Pod on
EACH node, and adds one automatically when a node joins.

Typical uses: log collectors, monitoring agents, network plugins. Anything that must
run on every machine.

  Deployment   "3 replicas, wherever they fit"      spec.replicas, rolling updates
  DaemonSet    "one per node"                        no replicas field

------------------------------------------------------------------------------------------
## 2. A DaemonSet manifest

It looks almost exactly like a Deployment, minus `replicas` and `strategy`:

```yaml
apiVersion: apps/v1
kind: DaemonSet                 # the only real difference at the top
metadata:
  name: log-agent
  namespace: demo
spec:
  selector:
    matchLabels:
      app: log-agent            # must match the template labels
  template:
    metadata:
      labels:
        app: log-agent
    spec:
      containers:
      - name: agent
        image: busybox:1.37
        command: ["sh", "-c", "sleep 1d"]
```

There's no `kubectl create daemonset`. The standard trick: generate a Deployment, then
change it in vim:

```bash
k create deploy log-agent -n demo --image=busybox:1.37 $do > ds.yaml
vim ds.yaml        # kind: DaemonSet, delete replicas, strategy and status
k apply -f ds.yaml
k get ds -n demo                # DESIRED / CURRENT / READY = number of nodes
k get pod -n demo -o wide       # NODE column: one Pod per node
```

------------------------------------------------------------------------------------------
## 3. Taints and tolerations: running on the control plane

Nodes can carry a TAINT, which repels Pods. Only Pods with a matching TOLERATION may be
scheduled there. Control-plane nodes are usually tainted, so normal workloads stay off:

    node-role.kubernetes.io/control-plane:NoSchedule

```bash
k describe node <node> | grep -i taints     # see a node's taints
```

A toleration goes in the Pod spec (for a DaemonSet: under `spec.template.spec`):

```yaml
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists          # the taint has no value, so "the key exists" is enough
        effect: NoSchedule
```

A toleration ALLOWS scheduling on a tainted node. It doesn't force it. The DaemonSet
does the "one per node" part.

Note for this lab: the k3d control plane here isn't tainted, so the toleration changes
nothing in practice. Real exam clusters are tainted, so it's still the right habit, and
the grader checks it's there.

------------------------------------------------------------------------------------------
## 4. Init containers: setup before the app starts

An init container runs to completion BEFORE the normal containers start. Several run one
after another. If one fails, the Pod retries it and the app never starts.

Use them to prepare things: generate a config file, wait for a database, download data.
They share volumes with the main containers, which is how they hand over files.

```yaml
    spec:
      volumes:
      - name: shared
        emptyDir: {}              # an empty directory that lives as long as the Pod
      initContainers:             # runs first, must exit 0
      - name: prepare
        image: busybox:1.37
        command: ["sh", "-c", "echo ready > /work/status"]
        volumeMounts:
        - name: shared
          mountPath: /work
      containers:                 # starts only after all init containers succeeded
      - name: app
        image: busybox:1.37
        command: ["sh", "-c", "cat /work/status; sleep 1d"]
        volumeMounts:
        - name: shared
          mountPath: /work
```

`k get pod` shows `Init:0/1` while init containers run. `k logs <pod> -c <init-name>`
shows an init container's output.

------------------------------------------------------------------------------------------
## 5. The Downward API: a Pod learning about itself

A container doesn't know which node or namespace it runs in. The Downward API passes
those facts in, as environment variables (or files):

```yaml
        env:
        - name: MY_NODE
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName        # filled in by Kubernetes at runtime
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
```

Available fields include metadata.name, metadata.namespace, spec.nodeName,
spec.serviceAccountName, status.podIP and status.hostIP. See them all with:

```bash
k explain pod.spec.containers.env.valueFrom.fieldRef
```

Shell quoting: inside `sh -c "..."`, write `$MY_NODE`; the container's shell expands it.

------------------------------------------------------------------------------------------
## 6. How this applies to question 24

  Task 1  Generate a Deployment for `node-agent` with $do, turn it into a DaemonSet, and
          add the toleration and the emptyDir volume under `spec.template.spec`.
  Task 2  Add an init container with env NODE_NAME from `spec.nodeName`, writing the
          required line into the shared volume.
  Task 3  The main container `agent` mounts the same volume and runs the given command.
  Task 4  `k get pod -n vela -o wide` shows which Pod runs on k3d-ckad-agent-0. Read the
          logs of its `agent` container (`-c agent`) into the file.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Leaving `replicas` or `strategy` in the YAML: a DaemonSet rejects them
  - Toleration at the wrong level: it belongs in the Pod template spec
  - Mounting the volume in only one container: both need the mount to share the file
  - Hardcoding the node name instead of using `fieldRef: spec.nodeName`
  - Reading logs without `-c agent`: kubectl may show the wrong container
  - `$(NODE_NAME)` vs `$NODE_NAME`: inside `sh -c`, use `$NODE_NAME`

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "DaemonSet"                       manifest example, how scheduling works
  Search "Taints and Tolerations"          toleration syntax and operators
  Search "Init Containers"                 behavior and examples
  Search "Expose Pod Information to Containers Through Environment Variables"
                                           the Downward API with fieldRef

See also: ckad explain 35 (init containers), ckad explain 16 (sidecars)

Now try it: ckad q 24
