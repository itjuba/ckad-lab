# Lesson 17: Kustomize bases and overlays

Curriculum: "Kustomize" (Application Deployment, 20%).

------------------------------------------------------------------------------------------
## 1. The problem Kustomize solves

The same app runs in dev, staging and production. The YAML is 95% identical: only the
namespace, replica count, image tag or a label differ. Copying the whole YAML per
environment means fixing every bug three times.

Kustomize keeps ONE copy of the shared YAML (the base) and a small file per environment
(an overlay) that lists only the differences. It's built into kubectl: no extra tool.

```
kustomize/
├── base/                     shared YAML
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml    lists the files that belong to the base
└── overlays/
    ├── dev/
    │   └── kustomization.yaml    "use ../../base, but in namespace dev"
    └── staging/
        └── kustomization.yaml    "use ../../base, but 2 replicas, newer image, ..."
```

The base is never edited for an environment. Overlays change things on the way out.

------------------------------------------------------------------------------------------
## 2. kustomization.yaml

The base just lists its files:

```yaml
# base/kustomization.yaml
resources:
- deployment.yaml
- service.yaml
```

An overlay points at the base and lists changes ("transformers"):

```yaml
# overlays/demo/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: demo                # sets metadata.namespace on EVERY resource
resources:
- ../../base                   # path to the base directory, relative to this file
replicas:
- name: web                    # the Deployment's name
  count: 3
images:
- name: nginx                  # the image name as written in the base (no tag)
  newTag: 1.29-alpine          # replace the tag  (newName: replaces the name/registry)
labels:
- pairs:
    team: demo                 # add this label to every resource's metadata
```

Other useful fields: `namePrefix` / `nameSuffix` (rename everything), `patches` (change
any field with a partial YAML), `configMapGenerator` (create ConfigMaps from files).

Labels: `labels:` adds the label to the resources' own metadata. The older
`commonLabels:` also adds it to selectors, and a Deployment's selector can't be changed
once it exists, so applying that over a running Deployment fails.

------------------------------------------------------------------------------------------
## 3. The commands

```bash
k kustomize overlays/demo           # RENDER only: prints the final YAML, changes nothing
k apply -k overlays/demo            # render AND apply (-k = kustomization directory)
k delete -k overlays/demo           # remove everything the overlay created
k diff -k overlays/demo             # what would change in the cluster
```

Always render first and read the output: is the namespace right? the replica count? the
image tag? the label?

`namespace:` in a kustomization does NOT create the Namespace. Create it first
(`k create ns demo`) or add a Namespace manifest to `resources`.

The kustomize version built into kubectl shows in `k version` (Kustomize Version).

------------------------------------------------------------------------------------------
## 4. How this applies to question 17

  First   Look around: `cat base/kustomization.yaml` and the dev overlay. Note the
          Deployment's name and how the base writes the image (name and tag).
  Task 1  Create the staging directory and its kustomization.yaml: point at the base, and
          add one field per requirement (namespace, replica count, image tag via `images`,
          label). Render it with `k kustomize` and check each value in the output.
  Task 2  Make sure the target namespace exists, then `k apply -k`. Check with
          `k get deploy,svc -n <namespace> --show-labels`.
  Never   touch base/ or overlays/dev/: the grader checks they're unchanged.

------------------------------------------------------------------------------------------
## 5. Common mistakes

  - Editing the base instead of overriding in the overlay
  - Wrong relative path in `resources:` (from overlays/staging it's ../../base)
  - `images: - name:` with the tag included, or a name that doesn't match the base exactly
  - `replicas: - name:` not matching the Deployment's name
  - Forgetting to create the namespace: apply fails with "namespaces ... not found"
  - `k apply -f` on the directory instead of `-k`: plain YAML files, no transformers

------------------------------------------------------------------------------------------
## 6. Docs (kubernetes.io)

  Search "Declarative Management of Kubernetes Objects Using Kustomize"
          (examples of resources, namespace, images, labels, patches, overlays)

Now try it: ckad q 17
