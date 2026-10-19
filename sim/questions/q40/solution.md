# Solution 40

A `Pending` Pod hasn't been placed on a node yet. The scheduler explains why in the Pod's
events:

```bash
k get pod -n volans -o wide                         # all Pending, NODE <none>
k describe pod volans-api-<xxxxx> -n volans         # one Pod by name: Events at the bottom
#   ... FailedScheduling ... 0/2 nodes are available: 2 node(s) didn't match Pod's node affinity/selector
k describe pod volans-api-<xxxxx> -n volans | grep FailedScheduling > /opt/course/40/api-reason

# or straight from the namespace's events:
k get events -n volans | grep volans-api
```

**2.** What does the Pod ask for?

```bash
k describe deploy volans-api -n volans | grep -i -A1 node-selectors     # disktype=ssd
k get nodes --show-labels | grep disktype                               # no node has it
k label node k3d-ckad-agent-0 disktype=ssd
k get pod -n volans -o wide                                             # Running on k3d-ckad-agent-0
```

**3. + 4.** The batch Pod asks for more CPU than any node has:

```bash
k describe pod volans-batch -n volans | grep FailedScheduling > /opt/course/40/batch-reason
#   ... 0/2 nodes are available: 2 Insufficient cpu ...

k get pod volans-batch -n volans -o yaml > 40.yaml
vim 40.yaml                    # requests: cpu: "64"  ->  cpu: 100m
k replace --force -f 40.yaml   # deletes the old Pod and creates the new one
k get pod volans-batch -n volans
```

Instead of `k get -o yaml`, you can also write a fresh Pod with
`k run volans-batch -n volans --image=nginx:1.29-alpine $do > 40.yaml` and add the
`resources` block.

Remember:
- kubectl (v1.37) only prints **Events** when you describe **one** object by name. With
  `-l` or several objects, add `--show-events=true` or use `k get events`.
- `Pending` + `FailedScheduling` = a scheduling problem: node selector/affinity, taints,
  or not enough CPU/memory. `ContainerCreating` or `ImagePullBackOff` happen *after*
  scheduling and point at volumes or images instead.
- `nodeSelector` matches **node labels**. `k get nodes --show-labels` shows them, and
  `k label node <node> key=value` adds one.
- Requests are what the scheduler reserves. `"64"` means 64 whole CPUs, while `100m` is a
  tenth of one.
