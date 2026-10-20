# Lesson 1: Namespaces, labels, selectors and annotations

Curriculum: "Use built-in CLI tools to monitor Kubernetes applications"
(Application Observability and Maintenance, 15%). Labels are also the glue behind
Services, Deployments and NetworkPolicies, so everything later builds on this lesson.

------------------------------------------------------------------------------------------
## 1. The problem

A real cluster holds hundreds of objects. On the exam you constantly need to answer
questions like "which Pods belong to team X?", "how many are there?", "which node runs
this Pod?". `kubectl get` plus labels and a few output options answer all of them.

------------------------------------------------------------------------------------------
## 2. Namespaces: folders for objects

A namespace groups objects. Names only have to be unique inside a namespace.

```bash
k get ns                         # list namespaces
k get pods -n lyra               # Pods in one namespace
k get pods -A                    # Pods in ALL namespaces (adds a NAMESPACE column)
```

Without `-n`, kubectl uses `default`. Forgetting `-n` is the #1 "it's not there!" mistake.

------------------------------------------------------------------------------------------
## 3. Labels: key=value tags you can select on

Labels live in `metadata.labels` of any object:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: search-ui
  labels:
    app: search                 # simple key
    tier: frontend
    nimbus.io/team: search      # prefixed key: <prefix>/<name>
```

Why they matter: a Service finds its Pods by label, a Deployment manages "its" Pods by
label, a NetworkPolicy picks Pods by label. Labels are how Kubernetes connects things.

```bash
k get pods --show-labels                 # all labels in one column
k get pods -L app,tier                   # one column per label key
k label pod search-ui env=prod           # add a label
k label pod search-ui env=dev --overwrite   # change it
k label pod search-ui env-               # remove it (key followed by -)
```

------------------------------------------------------------------------------------------
## 4. Selectors: filtering with -l

```bash
k get pods -l app=search                 # label equals value
k get pods -l app!=search                # label differs (or is missing)
k get pods -l nimbus.io/team             # label EXISTS, any value
k get pods -l '!nimbus.io/team'          # label is MISSING (quotes: ! is special in bash)
k get pods -l 'tier in (frontend,web)'   # value is one of a set
k get pods -l app=search,tier=frontend   # comma = AND (both must match)
```

`-l` works with every `get`, plus `delete`, `logs`, `describe` and more.

------------------------------------------------------------------------------------------
## 5. Annotations: information you can't select on

Annotations are key/value pairs too, but meant for notes and tool settings: a
description, an owner, a change cause, config for an ingress controller.

```yaml
metadata:
  annotations:
    nimbus.io/role: primary
    description: "search frontend, owned by team search"
```

```bash
k annotate pod search-ui owner=team-search      # add
k describe pod search-ui | grep -i -A3 annotations
```

The key difference: **`-l` only works on labels**. To find an object by annotation you
have to read the annotations: `describe` (search it with `less` + `/text`, or `grep`),
or `k get ... -o yaml`.

------------------------------------------------------------------------------------------
## 6. Output options you'll use all the time

```bash
k get pods -o wide             # adds IP and NODE columns
k get pods -o name             # pod/search-ui  (type/name, one per line)
k get pods --no-headers        # drops the NAME/READY/... header line
k get pods -o yaml             # the full object
```

Shell helpers that are enough for the exam:

```bash
k get pods -A -l app=search --no-headers | wc -l      # COUNT matching objects
k get ns --no-headers | awk '{print $1}'               # print only column 1 (the names)
k describe pods -A | less                              # then type /word and Enter to search
```

In `less`: `/text` searches, `n` jumps to the next match, `q` quits.

------------------------------------------------------------------------------------------
## 7. How this applies to question 1

  Task 1  "Namespaces that carry the label, any value" = a key-only selector. The file must
          hold NAMES only, one per line: no header, no STATUS/AGE columns.
  Task 2  "Across all namespaces" = -A. Count the matching Pods and make sure the header
          line isn't counted. The file holds just the number.
  Task 3  This is an ANNOTATION, so -l won't find it. Search the describe output of all
          Pods for the annotation, note which Pod has it, then read that Pod's node
          (the Node: line in describe, or the NODE column of -o wide).

------------------------------------------------------------------------------------------
## 8. Common mistakes

  - Writing whole table rows into an answer file instead of just the names
  - `wc -l` without `--no-headers`: the header line makes the count one too high
  - Forgetting -A and only searching the default namespace
  - Trying `-l nimbus.io/role=primary` on an annotation: it silently matches nothing
  - Writing the Pod name when the task asks for the Node name (read the question twice)

------------------------------------------------------------------------------------------
## 9. Docs (kubernetes.io)

  Search "Labels and Selectors"     selector syntax, set-based selectors
  Search "Annotations"              what they're for
  Search "kubectl Quick Reference"  the cheat sheet: get, -o, -l, sorting, formatting

See also: ckad explain 2 (Pods), ckad explain 10 (Services select Pods by label)

Now try it: ckad q 1
