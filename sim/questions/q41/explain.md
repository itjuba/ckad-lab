# Lesson 41: Giving a workload its own ServiceAccount

Curriculum: "Understand ServiceAccounts" and "Understand Application Security"
(Application Environment, Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem

Every Pod runs as a ServiceAccount (SA), its identity towards the Kubernetes API. If you
don't choose one, it's the namespace's `default` SA, shared by every Pod there.

Two security habits follow from that:

  - Give each app its OWN ServiceAccount. Then permissions (RBAC) can be granted to exactly
    that app, and you can see in the audit logs which app did what.
  - If the app never talks to the Kubernetes API (most web apps don't), don't give it an
    API token at all. A stolen token can't be misused if it was never mounted.

------------------------------------------------------------------------------------------
## 2. How a Pod gets its identity and token

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 2
  selector:
    matchLabels: {app: shop}
  template:
    metadata:
      labels: {app: shop}
    spec:
      serviceAccountName: shop-runner        # the identity of these Pods
      automountServiceAccountToken: false    # don't mount an API token
      containers:
      - name: web
        image: nginx:1.29-alpine
```

Both fields belong to the POD spec, so in a Deployment they go under `template.spec`,
next to `containers`.

By default, Kubernetes mounts a short-lived token for the SA into every container at:

    /var/run/secrets/kubernetes.io/serviceaccount/   (files: token, ca.crt, namespace)

`automountServiceAccountToken: false` switches that off. It can be set:

  - on the Pod spec              affects these Pods only (wins if both are set)
  - on the ServiceAccount        affects every Pod using that SA

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shop-runner
automountServiceAccountToken: false     # top level of the SA, not under spec
```

The field is `serviceAccountName`. An older field called `serviceAccount` still exists
but is deprecated.

------------------------------------------------------------------------------------------
## 3. Commands

```bash
k create sa shop-runner -n <ns>                         # sa = serviceaccount
k get sa -n <ns>

k set serviceaccount deploy shop shop-runner -n <ns>    # short: k set sa ...
#   changes the Pod template, so the Deployment rolls out new Pods

k edit deploy shop -n <ns>        # for fields without a set command (automount...)
k rollout status deploy shop -n <ns>

k explain pod.spec.automountServiceAccountToken
```

You can't change the ServiceAccount of a running Pod. A Deployment handles that by
replacing its Pods. A bare Pod you'd have to recreate.

------------------------------------------------------------------------------------------
## 4. Verifying in the running Pods

```bash
k get pod -n <ns>                                     # only new Pods, all Running
k describe pod <pod-name> -n <ns> | grep -i "service account"
#   Service Account:  shop-runner
k get pod <pod-name> -n <ns> -o yaml | grep serviceAccountName

k exec -n <ns> deploy/shop -- ls /var/run/secrets/kubernetes.io/serviceaccount
#   with automount off: "No such file or directory"
```

------------------------------------------------------------------------------------------
## 5. How this applies to question 41

  Task 1  One `create sa` command.
  Task 2  `k set sa` on the Deployment (or set serviceAccountName in the Pod template).
  Task 3  The task says where to put automount: false: the Pod template. `k edit` the
          Deployment and add it next to serviceAccountName.
  Task 4  Wait for the rollout. Old Pods running as `default` must be gone.
  Task 5  Ask a running Pod which SA it uses (describe or -o yaml) and write just the name.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Putting serviceAccountName or automountServiceAccountToken under the Deployment's own
    `spec` instead of `spec.template.spec`
  - Writing `automountServiceAccountToken: "false"` with quotes: it's a boolean
  - Checking an old Pod that still runs as `default`: wait for the rollout first
  - Creating the SA in the wrong namespace: SAs are namespaced, the Pod can only use one
    from its own namespace (otherwise the rollout gets stuck with a "not found" error)
  - Expecting a new SA to have permissions: it has none until a RoleBinding grants them

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Configure Service Accounts for Pods"   serviceAccountName, opting out of
                                                 automounting
  Search "Service Accounts"                      concept page

See also: ckad explain 5 (ServiceAccount tokens and RBAC permissions)

Now try it: ckad q 41
