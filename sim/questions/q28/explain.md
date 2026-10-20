# Lesson 28: Debugging NetworkPolicies across namespaces

Curriculum: "Demonstrate basic understanding of NetworkPolicies" (Services and
Networking, 20%).

------------------------------------------------------------------------------------------
## 1. What NetworkPolicies do

By default every Pod can talk to every other Pod, in every namespace. A NetworkPolicy is
a firewall rule for Pods: it says which traffic is ALLOWED to reach (ingress) or leave
(egress) the Pods it selects.

The rules that explain almost every NetworkPolicy puzzle:

  1. A Pod that no policy selects: all traffic allowed.
  2. Once ANY policy selects a Pod for ingress, that Pod only accepts what some
     policy explicitly allows. Everything else is dropped.
  3. Policies only ALLOW. There's no "deny" rule; denying = not allowing.
  4. Several policies selecting the same Pod ADD UP (the union of all allows).

------------------------------------------------------------------------------------------
## 2. Anatomy of a policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-access
  namespace: shop               # policies only apply to Pods in their own namespace
spec:
  podSelector:                  # WHICH Pods this policy protects
    matchLabels:
      app: db
  policyTypes: [Ingress]        # what it controls: Ingress, Egress, or both
  ingress:
  - from:                       # WHO may connect (a list of sources)
    - podSelector:
        matchLabels:
          role: db-client       # Pods with this label, in the SAME namespace
    ports:                      # on WHICH ports
    - protocol: TCP
      port: 5432
```

A "default deny" policy selects every Pod (`podSelector: {}`) and allows nothing:

```yaml
spec:
  podSelector: {}               # empty = all Pods in the namespace
  policyTypes: [Ingress]        # no ingress rules listed -> all ingress blocked
```

------------------------------------------------------------------------------------------
## 3. The `from` list: AND vs OR (the classic trap)

Each dash (`-`) in `from` is one SOURCE. Sources are OR'ed together. Selectors inside the
same item are AND'ed.

```yaml
  # ONE item with two selectors = AND:
  # "Pods labelled app=metrics that are ALSO in namespace monitoring"
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
      podSelector:              # no dash: same item as the namespaceSelector
        matchLabels:
          app: metrics
```

```yaml
  # TWO items = OR:
  # "ANY Pod in namespace monitoring, OR Pods labelled app=metrics in this namespace"
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
    - podSelector:              # dash: a separate source
        matchLabels:
          app: metrics
```

One dash of difference changes who gets in. Count the dashes.

Other facts you need:
  - A bare `podSelector` in `from` only matches Pods in the policy's OWN namespace.
  - To reach other namespaces, use `namespaceSelector`. Every namespace automatically
    has the label `kubernetes.io/metadata.name: <namespace name>`.
  - `k explain networkpolicy.spec.ingress.from` describes this AND behavior.

------------------------------------------------------------------------------------------
## 4. Debugging: read first, then test

```bash
k get netpol -n shop                         # which policies exist
k describe netpol db-access -n shop          # readable summary of selectors and ports
k get pod -n shop --show-labels              # do the clients carry the expected label?
k get ns --show-labels                       # namespace labels for namespaceSelector
```

Test real connections with a short timeout (-T 3), so blocked traffic fails fast:

```bash
k exec -n shop deploy/web -- wget -qO- -T 3 http://db          # same namespace
k exec -n other deploy/tool -- wget -qO- -T 3 http://db.shop   # from another namespace
```

Success prints the page. "download timed out" means blocked. "bad address" means a DNS
problem, not a policy (check the name).

------------------------------------------------------------------------------------------
## 5. Two ways to fix "client can't connect"

  A. Change the CLIENT to fit the policy: give its Pods the label the policy allows.
  B. Change the POLICY to allow the client: add a source to `from`.

For option A, put the label on the Deployment's Pod TEMPLATE
(`spec.template.metadata.labels`), not on running Pods. A label added with
`k label pod ...` disappears when the Pod is recreated.

```bash
k edit deploy web -n shop          # add the label under spec.template.metadata.labels
k rollout status deploy/web -n shop
```

------------------------------------------------------------------------------------------
## 6. How this applies to question 28

  Task 1  Read `cache-access` to see which label it expects from clients. You must not
          touch the policies, so fix the `web` side, in a way that survives Pod
          restarts. Then test with exec + wget.
  Task 2  Edit `cache-access` and add a source that matches app=metrics Pods ONLY in
          namespace hydrus-monitoring. Think hard about AND vs OR. Then test from the
          metrics Pods (must work) and from another Pod there (must time out).
  Leave `default-deny` exactly as it is.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Two dashes where you needed one: every Pod in hydrus-monitoring gets in
  - A bare podSelector for Pods in another namespace: it never matches them
  - `k label pod`: the fix is gone after the next restart
  - Deleting or "relaxing" default-deny to make things work
  - Testing without a timeout and waiting minutes for a blocked connection
  - Adding the new source as a separate ingress item without `ports`: that item then
    allows ALL ports. A `ports` list applies to every source in its own ingress item.

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Network Policies"        full YAML example, the AND/OR explanation, default
                                   deny examples (copy from here on the exam)
  Search "Declare Network Policy"  hands-on walkthrough with testing

See also: ckad explain 20 (writing NetworkPolicies from scratch)

Now try it: ckad q 28
