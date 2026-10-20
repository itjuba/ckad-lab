# Lesson 20: NetworkPolicies

Curriculum: "Demonstrate basic understanding of NetworkPolicies"
(Services and Networking, 20%).

------------------------------------------------------------------------------------------
## 1. The problem NetworkPolicies solve

By default every Pod can talk to every other Pod, in every namespace. If an attacker gets
into your frontend, they can reach your database directly. NetworkPolicies are firewall
rules for Pods: who may connect to whom, on which ports.

They're enforced by the cluster's network plugin. This cluster enforces them (k3s has a
built-in controller); on a cluster without enforcement they'd be silently ignored.

------------------------------------------------------------------------------------------
## 2. How a NetworkPolicy works

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web
  namespace: demo
spec:
  podSelector:                # WHICH Pods this policy protects (in this namespace)
    matchLabels:
      app: web
  policyTypes: [Ingress]      # which directions it controls: Ingress, Egress or both
  ingress:                    # list of ALLOWED incoming traffic
  - from:
    - podSelector:            # from Pods with this label (same namespace)
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```

The rules to remember:
  1. A Pod not selected by any policy: everything allowed (the default).
  2. Once a policy selects a Pod for a direction (Ingress or Egress), everything in that
     direction is DENIED except what some policy allows.
  3. Policies only ALLOW. They add up: traffic is allowed if any policy allows it.
  4. Ingress = traffic coming INTO the selected Pods. Egress = traffic going OUT of them.

------------------------------------------------------------------------------------------
## 3. Common building blocks

Deny all incoming traffic to every Pod in the namespace (a "default deny"):

```yaml
spec:
  podSelector: {}             # {} = every Pod in the namespace
  policyTypes: [Ingress]      # Ingress selected, but no ingress rules = nothing allowed
```

Sources and destinations (`from` for ingress, `to` for egress):
  podSelector         Pods in the policy's own namespace with these labels
  namespaceSelector   all Pods in namespaces with these labels
                      (every namespace has `kubernetes.io/metadata.name: <name>`)
  ipBlock             an IP range (cidr)

Egress with DNS: once a Pod's egress is restricted, it can't even look up names (DNS runs
in kube-system on port 53). Allow DNS explicitly, or nothing works by name:

```yaml
  policyTypes: [Egress]
  egress:
  - to:                       # rule 1: to db Pods on TCP 80
    - podSelector:
        matchLabels:
          app: db
    ports:
    - protocol: TCP
      port: 80
  - ports:                    # rule 2: DNS to anywhere (no "to" = any destination)
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

------------------------------------------------------------------------------------------
## 4. AND vs OR: the indentation trap

Each `-` starts a new list item. Items in a list are ORed; fields in one item are ANDed.

```yaml
  - from:
    - podSelector: {matchLabels: {app: api}}           # item 1
    - namespaceSelector: {matchLabels: {team: x}}      # item 2   -> api Pods OR team x
```

```yaml
  - from:
    - podSelector: {matchLabels: {app: api}}           # ONE item with both fields
      namespaceSelector: {matchLabels: {team: x}}      #          -> api Pods IN team x
```

The same goes for `to` and `ports`: in the same rule they must both match; as separate
rules (`- to:` and `- ports:`) either one is enough.

------------------------------------------------------------------------------------------
## 5. The commands

There's no `kubectl create networkpolicy`. Copy an example from the docs and edit it.

```bash
k get netpol -n demo                       # POD-SELECTOR shows who each policy protects
k describe netpol allow-web -n demo        # rules in plain words: check your selectors!
k explain networkpolicy.spec.ingress.from

# test connectivity: exec into a Pod and try to connect, with a short timeout
k exec -n demo deploy/frontend -- wget -qO- -T 3 http://web      # works: shows a page
k exec -n demo deploy/other    -- wget -qO- -T 3 http://web      # blocked: times out
k exec -n demo deploy/api -- nslookup db                         # is DNS still working?
```

`-T 3` makes wget give up after 3 seconds instead of hanging. A timeout means blocked.

------------------------------------------------------------------------------------------
## 6. How this applies to question 20

  Policy 1  The default-deny pattern from section 3.
  Policy 2  Selects the api Pods, one ingress rule: from frontend Pods, TCP 80.
  Policy 3  The same shape for the db Pods, allowing the api Pods.
  Policy 4  An EGRESS policy on the api Pods: one rule to the db Pods on TCP 80, and one
            rule for DNS on UDP and TCP 53 (otherwise `http://db` can't be resolved).
  Test      Use `k exec ... wget -T 3` for each allowed and blocked pair in the task.

Put all four in one file separated by `---` and apply once.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Forgetting DNS in an egress policy: everything by name fails
  - `podSelector: {}` vs a label: {} means EVERY Pod in the namespace
  - Splitting `to` and `ports` (or pod and namespace selectors) into separate items by
    accident, which turns AND into OR
  - Forgetting `policyTypes`, or listing Egress when you only meant Ingress
  - Writing the policy in the wrong namespace: it selects Pods in its own namespace only
  - Testing without `-T`: wget hangs and you think the terminal froze

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Network Policies"           concepts, full example, default deny/allow recipes
  Search "Declare Network Policy"     a guided walkthrough

See also: ckad explain 28 (debugging an existing NetworkPolicy, cross-namespace AND)

Now try it: ckad q 20
