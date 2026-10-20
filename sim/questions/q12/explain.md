# Lesson 12: PersistentVolumes and PersistentVolumeClaims (static)

Curriculum: "Utilize persistent and ephemeral volumes"
(Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem volumes solve

A container's filesystem is thrown away when the container restarts. Anything the app
wrote there is gone. For data that must survive (uploads, a database, website content)
you attach a volume that lives outside the container.

There are two kinds:

  ephemeral    lives as long as the Pod (emptyDir). Good for scratch space, sharing files
               between containers.
  persistent   lives independently of any Pod. A new Pod can mount the same data again.

Persistent storage in Kubernetes is split into two objects.

------------------------------------------------------------------------------------------
## 2. PV and PVC: supply and demand

  PersistentVolume (PV)        a piece of real storage: "1Gi on the node at /mnt/data"
                               cluster-wide object (NO namespace), usually made by an admin
  PersistentVolumeClaim (PVC)  a request for storage: "I need 1Gi, ReadWriteOnce"
                               namespaced, made by the app team

Kubernetes binds a PVC to a matching PV. The Pod never mentions the PV, only the claim:

  Pod --uses--> PVC --bound to--> PV --points at--> real storage (here: a node directory)

A PVC binds to a PV when ALL of these match:
  - the PV has at least the requested size
  - the access modes match
  - the storageClassName is the same on both (empty counts as a value too, see section 4)

Status values: a PVC is `Pending` (no match yet) or `Bound`. A PV is `Available`,
`Bound`, or `Released` (its claim was deleted).

------------------------------------------------------------------------------------------
## 3. The YAML

A PV using a directory on the node (`hostPath`). Note: no namespace.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
spec:
  capacity:
    storage: 2Gi                    # how big
  accessModes: ["ReadWriteOnce"]    # who may mount it, see below
  hostPath:
    path: /mnt/demo                 # directory on the node
```

A PVC that asks for storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
  namespace: demo                   # PVCs live in a namespace
spec:
  storageClassName: ""              # "" = no StorageClass, see section 4
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 2Gi
```

Access modes:
  ReadWriteOnce (RWO)      read-write by Pods on ONE node      the usual choice
  ReadOnlyMany (ROX)       read-only by many nodes
  ReadWriteMany (RWX)      read-write by many nodes (needs network storage like NFS)
  ReadWriteOncePod (RWOP)  read-write by exactly one Pod

Using the claim in a Pod (or in a Deployment's `spec.template.spec`) takes two parts:

```yaml
spec:
  containers:
  - name: web
    image: httpd:2.4-alpine
    volumeMounts:                   # 2. where it appears INSIDE the container
    - name: data                    #    must match the volume name below
      mountPath: /usr/local/apache2/htdocs
  volumes:                          # 1. which storage the Pod gets (Pod level)
  - name: data
    persistentVolumeClaim:
      claimName: demo-pvc           #    the PVC's name, not the PV's
```

------------------------------------------------------------------------------------------
## 4. StorageClasses and the "default class" trap

A StorageClass describes a kind of storage that can be created on demand (lesson 13).
This cluster has one, and it's marked default:

```bash
k get sc          # local-path (default)  rancher.io/local-path  ...  WaitForFirstConsumer
```

The trap: if a PVC leaves out `storageClassName`, Kubernetes fills in the DEFAULT class
(`local-path`). A PVC with class `local-path` never binds to your PV without a class.
Instead, it waits for local-path to create a brand-new volume.

  storageClassName missing  -> the default class gets filled in  -> ignores your static PV
  storageClassName: ""      -> "no class"                         -> binds to a classless PV

Extra option: `volumeName: demo-pv` in the PVC spec pins the claim to that exact PV.

------------------------------------------------------------------------------------------
## 5. The commands

There is NO `kubectl create pv` or `create pvc`. Copy a skeleton from the docs and edit it.
The page "Configure a Pod to Use a PersistentVolume for Storage" has a hostPath PV, a PVC
and a Pod, which is close to this question.

```bash
k explain pv.spec.hostPath                    # fields without the docs
k explain pvc.spec --recursive | less
k apply -f pv.yaml
k get pv                                      # STATUS, CLAIM, STORAGECLASS columns
k get pvc -n demo                             # STATUS Bound? VOLUME = which PV
k describe pvc demo-pvc -n demo               # Events explain why it's Pending

# Deployment: generate, then add volumes + volumeMounts in vim
k create deploy demo-web -n demo --image=httpd:2.4-alpine $do > deploy.yaml
```

------------------------------------------------------------------------------------------
## 6. How this applies to question 12

  Task 1  A PV is cluster-scoped: no namespace in its metadata. Capacity, access mode and
          hostPath come straight from the task. "No StorageClass" means you leave
          storageClassName out of the PV.
  Task 2  The PVC must bind to that PV. Think about section 4: what does the PVC need
          so the default class doesn't take over? Check with `k get pv,pvc -n andromeda`:
          both should say Bound, and the PVC's VOLUME column should show the PV's name.
  Task 3  Generate the Deployment with $do, then add a `volumes:` entry pointing at the
          claim and a `volumeMounts:` entry at the requested path.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Leaving storageClassName out of the PVC: it gets `local-path` and never binds to the PV
  - Putting a namespace on the PV (it's ignored; PVs are cluster-wide)
  - `claimName` set to the PV name instead of the PVC name
  - `volumes:` under the container instead of at Pod level (next to `containers:`)
  - The volumeMount `name` not matching the volume `name`
  - Size or access mode on the PVC not matching the PV: the PVC stays Pending

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Configure a Pod to Use a PersistentVolume for Storage"   PV + PVC + Pod example
  Search "Persistent Volumes"                                      concepts, access modes
  Search "Storage Classes"                                         the default class

See also: ckad explain 13 (dynamic provisioning with a StorageClass)

Now try it: ckad q 12
