# Lesson 0: Kubernetes & kubectl fundamentals

Read this once before question 1. Every other lesson builds on it.

------------------------------------------------------------------------------------------
## 1. What Kubernetes does

You give Kubernetes a description of what you want ("3 copies of my web app, reachable on
port 80"), and it makes it happen and KEEPS it that way: if a container crashes or a
machine dies, Kubernetes starts a replacement. This is called the desired state.

    you write:  "I want 3 replicas of nginx"     (desired state)
    Kubernetes: starts 3, watches them, replaces any that die   (actual state -> desired)

------------------------------------------------------------------------------------------
## 2. The cluster

A cluster is a group of machines (nodes):

  control plane   the brain: the API server (everything talks to it), the scheduler
                  (picks a node for each Pod), and controllers (keep desired = actual)
  worker nodes    run your containers

You never log in to nodes to start containers. You send requests to the API server, and
`kubectl` is the command-line tool that does that.

In this simulator: `k get nodes` shows k3d-ckad-server-0 (control plane) and
k3d-ckad-agent-0 (worker).

------------------------------------------------------------------------------------------
## 3. Objects: the things you create

Everything in Kubernetes is an object (also called a resource). The ones you'll use most:

  Pod          one or more containers that run together (the smallest unit)
  Deployment   keeps N identical Pods running and updates them safely
  Job/CronJob  runs Pods to completion, once or on a schedule
  Service      a stable name + IP that sends traffic to a group of Pods
  ConfigMap    configuration (non-secret key/value data) for Pods
  Secret       sensitive data (passwords, tokens) for Pods
  Namespace    a folder that groups objects (team-a, team-b, ...)

Objects build on each other:

    Deployment --creates--> ReplicaSet --creates--> Pods <--traffic-- Service

You usually create the top object (the Deployment), and Kubernetes creates the rest.

------------------------------------------------------------------------------------------
## 4. YAML: how an object is described

Every object has the same four top-level parts:

```yaml
apiVersion: v1            # which API version defines this kind (apps/v1 for Deployments)
kind: Pod                 # what type of object
metadata:                 # identity: name, namespace, labels, annotations
  name: web
  namespace: lyra
  labels:
    app: web              # labels: key/value tags used to SELECT objects (see section 6)
spec:                     # the desired state: what you want
  containers:
  - name: web             # "-" starts an item in a list
    image: nginx:1.29-alpine
    ports:
    - containerPort: 80
status: {}                # the actual state, filled in by Kubernetes (you never write it)
```

YAML rules that cost points when you get them wrong:
  - Indentation is meaning. Use 2 spaces, NEVER tabs.
  - `key: value` needs a space after the colon.
  - `- item` is a list entry. `containers:` is a list, even with one container.

Don't memorise fields: `k explain pod.spec.containers` shows them (section 8).

------------------------------------------------------------------------------------------
## 5. Namespaces

A namespace groups objects and keeps names separate (two teams can both have a Pod called
`web`). Most commands work in ONE namespace, `default` unless you say otherwise:

```bash
k get pods                 # namespace "default"
k get pods -n lyra         # namespace "lyra"
k get pods -A              # all namespaces
k get ns                   # list namespaces
```

On the exam, almost every task names a namespace. Forgetting `-n <ns>` is the #1 way to
create the right thing in the wrong place, which scores zero.

------------------------------------------------------------------------------------------
## 6. Labels and selectors: how objects find each other

Labels are tags on objects (`app=web`, `tier=backend`). Selectors pick objects by label.
This is how a Deployment knows which Pods are "its" Pods, and how a Service knows where to
send traffic:

```yaml
# Service: "send traffic to every Pod labelled app=web"
spec:
  selector:
    app: web
```

```bash
k get pods --show-labels          # see labels
k get pods -l app=web             # select by label
k get pods -l 'app in (web,api)'  # several values
k label pod web tier=frontend     # add a label
k label pod web tier-             # remove it (trailing minus)
```

If a Service's selector doesn't match the Pod labels, the Service has no endpoints and
traffic goes nowhere. You'll debug exactly that in later questions.

Annotations look like labels but can't be selected on. They hold notes for people and tools.

------------------------------------------------------------------------------------------
## 7. kubectl: the commands you'll use all the time

The `k` alias is preset (k = kubectl). The pattern is `k <verb> <type> <name> [flags]`:

```bash
# Look
k get pods                         # list (short status)
k get pods -o wide                 # + IP and node
k get pod web -o yaml              # the full object as YAML
k describe pod web                 # human-readable details + Events (why something fails)
k logs web                         # container output   (-c <container>, --previous)
k exec web -- ls /                 # run a command inside the container
k exec -it web -- sh               # open a shell inside it (exit to leave)

# Create
k run web --image=nginx            # a Pod
k create deploy web --image=nginx --replicas=3
k create <type> --help             # every create command has examples
k apply -f file.yaml               # create or update from a file

# Change
k edit deploy web                  # opens the live object in vim
k scale deploy web --replicas=5
k set image deploy/web web=nginx:1.29-alpine
k label / k annotate ...

# Remove
k delete pod web
k delete pod web --force --grace-period=0   # instantly (= $now)
```

Short names save typing: po (pods), deploy, svc, ns, cm (configmaps), sa, pv, pvc, netpol.
`k api-resources` lists them all.

------------------------------------------------------------------------------------------
## 8. The exam workflow: generate -> edit -> apply

Writing YAML by hand is slow and error-prone. Let kubectl write the skeleton:

```bash
export do="--dry-run=client -o yaml"       # once per terminal session
k run web --image=nginx --port=80 $do > web.yaml   # nothing is created yet
vim web.yaml                               # add what the command can't set
k apply -f web.yaml
```

`--dry-run=client -o yaml` means "show me the object you WOULD create, as YAML". When you
need a field you don't remember:

```bash
k explain pod.spec.containers.livenessProbe          # what the field is, its sub-fields
k explain deploy.spec.strategy --recursive           # the whole structure
```

and for longer snippets, kubernetes.io/docs (allowed on the exam).

Minimal vim: `i` = type, `Esc` = stop typing, `:wq` = save + quit, `:q!` = quit without
saving, `dd` = delete line, `u` = undo, `/text` = search.

------------------------------------------------------------------------------------------
## 9. Reading what went wrong

When something doesn't work, look in this order:

  1. k get pods -n <ns>                  STATUS: Running? Pending? CrashLoopBackOff?
  2. k describe pod <name> -n <ns>       Events at the bottom say WHY
  3. k logs <name> -n <ns>               what the app printed (--previous after a crash)

Common statuses: Pending (not scheduled yet: resources, node selector, volume),
ContainerCreating (pulling the image, mounting volumes), CrashLoopBackOff (the app keeps
exiting), ImagePullBackOff (wrong image name or tag), Completed (a Job's Pod finished).

------------------------------------------------------------------------------------------
## 10. How this simulator works

  ckad course         this course: lesson 0 + every lesson in learning order
  ckad next           the next question in the learning path
  ckad explain <n>    the theory behind question n   (read it BEFORE the question)
  ckad q <n>          the question itself
  ckad check <n>      grade your work, task by task
  ckad solution <n>   the reference solution (only when stuck)
  ckad reset <n>      start question n over

Answers that go into files live in /opt/course/<n>/. The grader checks RESULTS (file
contents and the cluster), never which commands you typed, just like the real exam.

Next step: ckad next
