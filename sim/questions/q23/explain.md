# Lesson 23: Custom resources (CRDs) and removed API versions

Curriculum: "Discover and use resources that extend Kubernetes (CRD, Operators)"
(Application Environment, Configuration and Security, 25%) and "Understand API
deprecations" (Application Observability and Maintenance, 15%).

------------------------------------------------------------------------------------------
## 1. Extending Kubernetes with new resource types

Kubernetes ships with built-in types: Pod, Deployment, Service, and so on. Tools often
need their own. A backup tool wants you to say "back up X every night, keep 7 days" as a
Kubernetes object, just like you'd write a Deployment.

  CustomResourceDefinition (CRD)   teaches the API server a NEW type, e.g. "Backup"
  Custom resource (CR)             one object of that type, e.g. the Backup "nightly"
  Operator (controller)            a program that watches those objects and does the work

On the CKAD you don't write CRDs or operators. You DISCOVER a CRD someone installed, and
CREATE custom resources with it, exactly like any other object.

------------------------------------------------------------------------------------------
## 2. What a CRD tells you

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backups.nimbus.io          # always <plural>.<group>
spec:
  group: nimbus.io                 # -> your objects use apiVersion: nimbus.io/<version>
  scope: Namespaced                # objects live in a namespace (or "Cluster")
  names:
    kind: Backup                   # -> kind: Backup
    plural: backups                # -> kubectl get backups
    shortNames: [bk]               # -> kubectl get bk
  versions:
  - name: v1                       # -> apiVersion: nimbus.io/v1
    served: true
    storage: true
    schema:                        # which fields `spec` may have, their types, which
      openAPIV3Schema: ...         #    are required; the API server enforces it
```

A custom resource then looks like any other manifest:

```yaml
apiVersion: nimbus.io/v1           # <group>/<version>, NOT the CRD's name
kind: Backup
metadata:
  name: example
  namespace: some-namespace
spec:
  someField: some-value            # names and types come from the CRD schema
```

------------------------------------------------------------------------------------------
## 3. Discovering a CRD

```bash
k get crd                                  # all CRDs in the cluster
k api-resources --api-group=nimbus.io      # NAME, SHORTNAMES, APIVERSION, KIND
k explain backup                           # works for CRDs that have a schema
k explain backup.spec                      # field names, types, which are -required-
k describe crd backups.nimbus.io           # the full definition
k get bk -A                                # list objects using the short name
```

`k explain` is the fastest way to get field names right. It also marks required fields,
so you know what the API server will insist on.

YAML gotcha for schedules: a value starting with `*` must be quoted (`"0 2 * * *"`),
because a bare `*` means something special in YAML. Integers stay unquoted (`7`, not
`"7"`), or the schema rejects them.

------------------------------------------------------------------------------------------
## 4. API versions, deprecation and removal

Every type lives in an API group and version: `apps/v1` Deployment, `batch/v1` Job.
New features start in beta versions (`v1beta1`, `v2beta2`), later graduate to stable
(`v1`, `v2`). The beta version is then deprecated and, a few releases later, REMOVED.
A manifest that still uses a removed version fails to apply:

    no matches for kind "HorizontalPodAutoscaler" in version "autoscaling/v2beta1"

Removals worth knowing:

  autoscaling/v2beta1, v2beta2   HorizontalPodAutoscaler  -> autoscaling/v2   (fields moved)
  policy/v1beta1                 PodDisruptionBudget      -> policy/v1        (same fields)
  batch/v1beta1                  CronJob                  -> batch/v1
  networking.k8s.io/v1beta1      Ingress                  -> networking.k8s.io/v1
                                                             (fields moved)
  extensions/v1beta1, apps/v1beta2 Deployment             -> apps/v1

Sometimes only `apiVersion` changes. Sometimes fields moved too. Then kubectl refuses the
old field ("unknown field ..."), and you look up the new structure.

```bash
k api-versions | grep -e autoscaling -e policy     # versions this cluster serves
k api-resources | grep -i -e horizontal -e disruption   # current version per type
k explain hpa.spec.metrics --api-version=autoscaling/v2 --recursive   # new structure
```

There's no `kubectl convert` on the exam. You edit the files by hand.

Trick: let kubectl generate a modern object and copy its structure:

```bash
k create deploy demo --image=nginx $do > /tmp/d.yaml
k autoscale -f /tmp/d.yaml --min=2 --max=5 --cpu=80% $do      # prints an autoscaling/v2 HPA
k create pdb demo --selector=app=demo --min-available=1 $do  # prints a policy/v1 PDB
```

In `autoscaling/v2`, a CPU target looks like this (old beta versions used one flat field
instead):

```yaml
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization          # percent of the Pods' CPU request
        averageUtilization: 80
```

The two types in this question, briefly:
  - HorizontalPodAutoscaler (HPA): scales a Deployment between min and max replicas
    based on metrics such as CPU.
  - PodDisruptionBudget (PDB): keeps at least N Pods of an app running during voluntary
    disruptions, such as a node being drained.

------------------------------------------------------------------------------------------
## 5. How this applies to question 23

  Task 1  Find the CRD's group, version, kind and field names with `api-resources` and
          `explain`. One field name isn't simply "retention". Write a small manifest in
          the right namespace and apply it.
  Task 2  The SHORTNAMES column of `k api-resources` has the answer.
  Task 3  Apply the folder first to see the errors. Check which versions are served.
          For each file in /opt/course/23/legacy/, fix `apiVersion`, and where fields
          moved, restructure them (compare with `explain --api-version` or a generated
          object). Edit the files themselves, then `k apply -f` the folder.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - `apiVersion: backups.nimbus.io/v1`: the CRD's name is not the group. Use nimbus.io/v1
  - Unquoted cron schedules, or a quoted number for an integer field
  - Guessing field names instead of reading `k explain backup.spec`
  - Changing only the HPA's apiVersion: the old metric field is rejected in v2
  - Fixing a copy elsewhere: the task says to update the files in place
  - Forgetting the namespace when creating the custom resource

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Deprecated API Migration Guide"   every removed version and what replaces it
  Search "Custom Resources"                 CRD concepts
  Search "Horizontal Pod Autoscaling"       HPA concepts and the autoscaling/v2 fields
  Search "Specifying a Disruption Budget"   PDB examples

See also: ckad explain 21 (requests, which HPA CPU percentages are based on)

Now try it: ckad q 23
