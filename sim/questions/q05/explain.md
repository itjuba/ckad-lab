# Lesson 5: ServiceAccounts, tokens and RBAC

Curriculum: "Understand ServiceAccounts" and "Understand authentication, authorization
and admission control" (Application Environment, Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem RBAC solves

Every request to the Kubernetes API (every `kubectl` command) answers two questions:

  1. WHO are you?          -> authentication (user certificate or ServiceAccount token)
  2. Are you ALLOWED to?   -> authorization  (RBAC: Role-Based Access Control)

Example: a CI pipeline should read Pods and their logs, but must never delete anything.
RBAC lets you write exactly that down.

------------------------------------------------------------------------------------------
## 2. ServiceAccount = an identity for programs

Humans use user accounts. Programs (a CI system, an app inside a Pod) use a ServiceAccount.

  - A ServiceAccount (SA) lives in a namespace:  orion/orion-ci
  - Every namespace has one called `default`
  - Pods run as an SA (`spec.serviceAccountName`; `default` if you don't set one)
  - A new SA can do NOTHING until you grant it permissions

```bash
k create sa orion-ci -n orion          # create one
k get sa -n orion                      # list them
```

Its full username, which you need for testing, is:

    system:serviceaccount:<namespace>:<name>      e.g. system:serviceaccount:orion:orion-ci

------------------------------------------------------------------------------------------
## 3. Tokens: how an SA proves who it is

A program authenticates as an SA with a token (a long string, like a password).

  - Pods get a short-lived token mounted automatically at
    /var/run/secrets/kubernetes.io/serviceaccount/token
  - For an outside system (like CI) an admin can create a long-lived token stored in a
    Secret of type `kubernetes.io/service-account-token`. Kubernetes fills in the token.
  - `k create token orion-ci -n orion` prints a short-lived token on demand.

A token Secret looks like this:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: orion-ci-token
  namespace: orion
  annotations:
    kubernetes.io/service-account.name: orion-ci   # <- which SA it belongs to
type: kubernetes.io/service-account-token          # <- the type to look for
data:
  token: ZXlKaGJHY2lPaUpTVXpJMU5pSX...              # <- base64 encoded
```

Reading it:

```bash
k get secret -n orion                     # TYPE column shows which Secrets are SA tokens
k describe secret orion-ci-token -n orion # shows the SA annotation AND the token DECODED
k get secret orion-ci-token -n orion -o yaml   # shows the token base64 ENCODED
echo '<base64 value>' | base64 -d              # decode it yourself
```

Secret values under `data:` are always base64 encoded. That's encoding, not encryption.
`describe` decodes the token of SA token Secrets for you. For other Secrets it only shows
the size in bytes.

------------------------------------------------------------------------------------------
## 4. RBAC: Role + RoleBinding

RBAC uses two objects. Keep them apart in your head:

  Role          WHAT is allowed   "get, list, watch on pods"           (a list of rules)
  RoleBinding   WHO gets it       "the SA orion-ci gets Role pod-reader"

  ServiceAccount orion-ci  <--RoleBinding orion-ci-pod-reader-->  Role pod-reader

A Role is a list of rules. Each rule = API group + resources + verbs:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: orion            # a Role only works inside its namespace
rules:
- apiGroups: [""]             # "" = the core group (pods, services, secrets, configmaps...)
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]     # logs are a SUBRESOURCE: separate from "pods"
  verbs: ["get"]
```

Common verbs: get (one object), list (all), watch (stream changes), create, update,
patch, delete. Read-only = get + list + watch.

Which API group? Deployments are in "apps", Jobs in "batch", Pods/Services/Secrets in "".
`k api-resources` shows the group (APIVERSION column) of every resource.

The binding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: orion-ci-pod-reader
  namespace: orion
roleRef:                       # which Role (can't be changed later)
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:                      # who gets it
- kind: ServiceAccount
  name: orion-ci
  namespace: orion
```

Role vs ClusterRole: a Role works in one namespace; a ClusterRole is cluster-wide (or for
cluster-scoped things like nodes). RoleBinding vs ClusterRoleBinding likewise. CKAD tasks
are almost always Role + RoleBinding in one namespace.

------------------------------------------------------------------------------------------
## 5. The commands (no YAML typing needed for most of it)

```bash
# Role with one rule
k create role pod-reader -n orion --verb=get,list,watch --resource=pods

# Different verbs for different resources -> generate, then add the 2nd rule in vim
k create role pod-reader -n orion --verb=get,list,watch --resource=pods $do > role.yaml

# Binding. Note the format namespace:name
k create rolebinding orion-ci-pod-reader -n orion --role=pod-reader \
  --serviceaccount=orion:orion-ci
#   for a human user instead:      --user=jane
#   for a ClusterRole instead:     --clusterrole=view

# Inspect
k get role,rolebinding -n orion
k describe role pod-reader -n orion
```

------------------------------------------------------------------------------------------
## 6. Testing permissions: kubectl auth can-i

`can-i` asks the API "would this be allowed?". `--as` impersonates someone else:

```bash
k auth can-i list pods -n orion --as=system:serviceaccount:orion:orion-ci            # yes
k auth can-i get pods --subresource=log -n orion --as=system:serviceaccount:orion:orion-ci
k auth can-i delete pods -n orion --as=system:serviceaccount:orion:orion-ci          # no
k auth can-i --list -n orion --as=system:serviceaccount:orion:orion-ci   # all it may do
```

The answer is printed as exactly `yes` or `no`, so it's easy to save to a file with `>`.

------------------------------------------------------------------------------------------
## 7. How this applies to question 5

  Task 1  Several Secrets exist in `orion`. Find the one whose TYPE is
          service-account-token AND whose annotation points at orion-ci. Write the token
          DECODED (describe shows it decoded; with -o yaml you'd use base64 -d).
  Task 2  Pods need get/list/watch, logs need only get, so you need two rules: generate
          with `k create role ... $do`, add the pods/log rule in vim. Then one
          `k create rolebinding`.
  Task 3  One `k auth can-i ... --as=...` command, output redirected into the file.

------------------------------------------------------------------------------------------
## 8. Common mistakes

  - Wrong name format: --serviceaccount=orion:orion-ci (create rolebinding)
                      --as=system:serviceaccount:orion:orion-ci (auth can-i)
  - Forgetting -n orion: the Role/RoleBinding land in `default` and grant nothing in orion
  - Granting "pods" and expecting logs to work: logs need "pods/log"
  - Writing the base64 value instead of the decoded token
  - Picking a Secret by its name instead of checking its type and SA annotation

------------------------------------------------------------------------------------------
## 9. Docs (kubernetes.io)

  Search "Using RBAC Authorization"            Role/RoleBinding YAML and kubectl examples
  Search "Configure Service Accounts for Pods" ServiceAccounts and tokens
  Search "kubectl auth can-i"                  the can-i reference

Now try it: ckad q 5
