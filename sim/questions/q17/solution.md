# Solution 17

```bash
cd /opt/course/17/kustomize
cat base/kustomization.yaml overlays/dev/kustomization.yaml    # copy the dev layout
mkdir overlays/staging
vim overlays/staging/kustomization.yaml
```

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: sirius-staging        # sets metadata.namespace on every resource
resources:
- ../../base
replicas:
- name: sirius-api               # Deployment name
  count: 2
images:
- name: nginx                    # image name as written in the base (without the tag)
  newTag: 1.29-alpine
labels:
- pairs:
    env: staging
```

```bash
k kustomize overlays/staging     # look at the output before applying
k create ns sirius-staging       # kustomize won't create the namespace for you
k apply -k overlays/staging
k get deploy,svc -n sirius-staging --show-labels
```

Remember:
- `k kustomize <dir>` only renders and `k apply -k <dir>` renders and applies. Use the first to check your work.
- The `namespace:` field doesn't create the Namespace. Create it yourself, or add a Namespace manifest to `resources`.
- `commonLabels: {env: staging}` also works, but it adds the label to selectors as well. On an existing Deployment that fails, because selectors can't be changed.
- Patching the replica count with `patches:` is also fine. The `replicas:` field is just shorter.
