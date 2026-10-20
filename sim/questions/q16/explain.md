# Lesson 16: Multi-container Pods and native sidecars

Curriculum: "Understand multi-container Pod design patterns (e.g. sidecar, init and
others)" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. Why put more than one container in a Pod?

A Pod can run several containers that belong together. They share:
  - the network: same IP, they reach each other on `localhost`
  - volumes: a volume mounted in both containers is the same files

That lets you add a helper next to an app WITHOUT changing the app's image.

Common patterns:
  init container   runs BEFORE the app, to completion (prepare files, wait for a database)
  sidecar          runs NEXT TO the app the whole time (ship logs, a proxy, sync files)
  adapter          converts the app's output into another format
  ambassador       a local proxy the app talks to instead of the outside world

------------------------------------------------------------------------------------------
## 2. The logging problem this question solves

`kubectl logs` only shows what a container writes to stdout/stderr. Some apps write their
log to a FILE instead, so `kubectl logs` shows nothing.

The fix: put the log file on a shared volume and run a sidecar that prints the file to
ITS stdout. Then `kubectl logs <pod> -c <sidecar>` shows the app's log.

  app container  --writes-->  /var/log/app/app.log  (emptyDir volume, shared)
  sidecar        --tail -F--> its own stdout  -->  kubectl logs -c sidecar

`tail -F` (capital F) keeps following the file and retries until it exists, which matters
when the sidecar starts before the app has created the file. Lowercase `-f` gives up if
the file isn't there yet.

------------------------------------------------------------------------------------------
## 3. Init containers vs native sidecars

Init containers (`spec.initContainers`) run one after another, each to completion, before
the regular containers start. A container that never exits (like `tail -F`) would block
the Pod forever in `Init:0/1`.

A NATIVE sidecar is an init container with `restartPolicy: Always` on the container:

```yaml
spec:
  initContainers:
  - name: log-tail
    image: busybox:1.37
    restartPolicy: Always            # THIS makes it a native sidecar
    command: ["tail", "-F", "/var/log/app/app.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  containers:
  - name: app
    image: busybox:1.37
    command: ["sh", "-c", "while true; do date >> /var/log/app/app.log; sleep 2; done"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}                     # lives as long as the Pod
```

What `restartPolicy: Always` on an init container changes:
  - Kubernetes starts it, but doesn't wait for it to exit before starting the app
  - it's restarted if it crashes, and stays up for the whole life of the Pod
  - it's stopped AFTER the app containers when the Pod shuts down
  - it counts in READY: an app + one sidecar shows `2/2`

The older way (a second entry under `containers:`) also runs side by side, but has no
start/stop order guarantee. The task says which one it wants.

`restartPolicy` here is a CONTAINER field. Don't confuse it with the Pod-level
`spec.restartPolicy`.

------------------------------------------------------------------------------------------
## 4. The commands

```bash
k edit deploy web -n demo                   # add the initContainers block; saving rolls out
k rollout status deploy web -n demo
k get pod -n demo                           # READY 2/2
k describe pod <pod> -n demo                # "Init Containers:" section shows the sidecar
k logs -n demo deploy/web -c log-tail       # -c picks the container
k logs -n demo deploy/web -c log-tail --tail=20 > /path/file
k explain pod.spec.initContainers.restartPolicy
```

With several containers, `k logs` without `-c` picks the default (first app) container and
prints which one it chose. Always name the container you want.

------------------------------------------------------------------------------------------
## 5. How this applies to question 16

  Task 1  The Deployment already has an emptyDir volume for its log. Look at its YAML
          first: what's the volume called, and where does the app write? Then add an
          `initContainers:` entry (inside the Pod template's spec) with the name, image and
          command from the task, mounting that same volume, plus the one field that makes
          it a native sidecar.
  Task 2  After the rollout, `k logs ... -c <sidecar>` and redirect into the file.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Adding the sidecar under `containers:` when a native sidecar was asked for
  - Forgetting `restartPolicy: Always`: the Pod hangs in `Init:0/1`
  - Setting restartPolicy at the Pod level instead of on the init container
  - Mounting a NEW volume instead of the existing one: the sidecar sees an empty directory
  - `kubectl logs` without `-c`: you get the app container's (empty) output
  - `tail -f` instead of `tail -F`: exits if the file doesn't exist yet

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Sidecar Containers"                  native sidecars, restartPolicy: Always
  Search "Init Containers"                     how init containers run
  Search "Communicate Between Containers in the Same Pod Using a Shared Volume"

See also: ckad explain 36 (two regular containers sharing a volume),
          ckad explain 35 (init container), ckad explain 24 (DaemonSet + init container)

Now try it: ckad q 16
