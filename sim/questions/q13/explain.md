# Lesson 13: Dynamic provisioning, StorageClasses and WaitForFirstConsumer

Curriculum: "Utilize persistent and ephemeral volumes"
(Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem dynamic provisioning solves

With static storage (lesson 12) an admin creates every PersistentVolume by hand before
anyone can claim it. That doesn't scale. With dynamic provisioning you only create the
PVC, and Kubernetes creates a matching PV for you, on demand.

  static:   admin creates PV  ->  you create PVC  ->  they bind
  dynamic:  you create PVC (with a StorageClass) -> the provisioner creates a PV -> bound

------------------------------------------------------------------------------------------
## 2. StorageClass = a recipe for creating volumes

A StorageClass names a provisioner (the program that creates the real storage) and its
settings. Cloud clusters have classes for disks; this k3d cluster has `local-path`, which
creates a directory on the node.

```bash
k get sc
# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```

The columns:
  PROVISIONER         who creates the volumes
  RECLAIMPOLICY       Delete = the PV and its data are deleted when the PVC is deleted
                      Retain = the PV and data stay behind
  VOLUMEBINDINGMODE   WHEN the volume is created (section 3)
  (default)           used for every PVC that doesn't name a class

A PVC that uses it:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-cache
  namespace: demo
spec:
  storageClassName: local-path      # which recipe
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
```

The PV that gets created has a generated name like `pvc-3f6c1e2a-...`. You read it from
the PVC's VOLUME column; you never pick it yourself.

------------------------------------------------------------------------------------------
## 3. volumeBindingMode: Immediate vs WaitForFirstConsumer

  Immediate              the PV is created as soon as the PVC exists
  WaitForFirstConsumer   the PV is created only when a Pod that uses the PVC is scheduled

Why wait? A local volume lives on one node. If it were created right away on node A, the
Pod might later need to run on node B and could never use it. Waiting lets the scheduler
pick the node first, then the volume is created on that node.

So with WaitForFirstConsumer this is NORMAL, not an error:

```bash
k get pvc demo-cache -n demo          # STATUS: Pending   (no Pod uses it yet)
k describe pvc demo-cache -n demo     # Events at the bottom explain why
```

The event says the claim is waiting for its first consumer to be created before binding.
As soon as a Pod mounts the claim, the PV appears and the PVC turns `Bound`.

Note: kubectl v1.37 shows Events only when you describe ONE object by name. With `-l`
or several objects they're hidden; use the name, `--show-events=true`, or
`k get events -n demo`.

------------------------------------------------------------------------------------------
## 4. Mounting the claim in a Pod

`kubectl run` can't add volumes, so generate YAML and add two blocks:

```bash
k run demo-writer -n demo --image=busybox:1.37 $do \
  -- sh -c 'while true; do date >> /data/log.txt; sleep 10; done' > pod.yaml
vim pod.yaml
```

```yaml
spec:
  containers:
  - name: demo-writer
    image: busybox:1.37
    args: ["sh", "-c", "while true; do date >> /data/log.txt; sleep 10; done"]
    volumeMounts:                   # inside the container
    - name: cache
      mountPath: /data
  volumes:                          # Pod level, next to containers
  - name: cache
    persistentVolumeClaim:
      claimName: demo-cache         # the PVC name
```

Check it works:

```bash
k get pvc,pv -n demo                          # PVC Bound, VOLUME = pvc-<uid>
k exec -n demo demo-writer -- cat /data/log.txt
```

`k get pvc --no-headers | awk '{print $3}'` prints just the VOLUME column (the PV name).

------------------------------------------------------------------------------------------
## 5. How this applies to question 13

  Task 1  A PVC with the class, size and access mode from the task (copy a PVC from the
          docs; there's no imperative command).
  Task 2  Look at the PVC BEFORE creating any Pod. Its STATUS column is the first file.
          `k describe pvc <name>` shows the event that explains it; its message is the
          second file.
  Task 3  Generate the Pod with `k run ... $do -- sh -c '...'`, then add `volumes` and
          `volumeMounts` (mount path from the task).
  Task 4  Once the Pod runs, the PVC is Bound. Read the PV name from the VOLUME column.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Thinking Pending means you did something wrong and "fixing" it before saving the status
  - Creating the Pod first: then the status is already Bound
  - Writing the PVC's name instead of the PV's name (pvc-<uid>) for the volume
  - A busybox Pod without a long-running command: it exits and keeps restarting
  - Describing several objects at once and finding no Events (v1.37 behavior)

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Storage Classes"                                         volumeBindingMode
  Search "Dynamic Volume Provisioning"                             how it works
  Search "Configure a Pod to Use a PersistentVolume for Storage"   PVC + Pod YAML

See also: ckad explain 12 (static PV and PVC, the default-class trap)

Now try it: ckad q 13
