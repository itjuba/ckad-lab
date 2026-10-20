# Lesson 9: securityContext, capabilities, and turning a Pod into a Deployment

Curriculum: "Understand Application Security (SecurityContexts, Capabilities, etc.)"
(Application Environment, Configuration and Security, 25%), plus "Utilize persistent and
ephemeral volumes" for the emptyDir part.

------------------------------------------------------------------------------------------
## 1. The problem

By default many images run their process as root (user ID 0), with a writable filesystem
and Linux privileges the app never needs. If the app gets hacked, the attacker inherits
all of that. A securityContext takes those powers away: least privilege.

------------------------------------------------------------------------------------------
## 2. Two levels

```yaml
spec:
  securityContext:                  # POD level: applies to every container in the Pod
    runAsUser: 1000                 # processes run as user ID 1000
    runAsGroup: 3000                # ...with primary group ID 3000
    fsGroup: 2000                   # mounted volumes get group 2000 (so the app can write)
    runAsNonRoot: true              # refuse to start a container that would run as root
  containers:
  - name: app
    image: busybox:1.37
    securityContext:                # CONTAINER level: only this container
      allowPrivilegeEscalation: false   # a process can't gain more rights than its parent
      readOnlyRootFilesystem: true      # the image's filesystem can't be written to
      privileged: false                 # no host-level access
      capabilities:
        drop: ["ALL"]                   # remove every Linux capability
        add: ["NET_BIND_SERVICE"]       # ...then add back only what's needed
```

Which field lives where (check with `k explain` when unsure):

  Pod only        fsGroup, supplementalGroups, sysctls
  Container only  allowPrivilegeEscalation, readOnlyRootFilesystem, privileged,
                  capabilities
  Both            runAsUser, runAsGroup, runAsNonRoot, seccompProfile
                  (the container value wins over the Pod value)

```bash
k explain pod.spec.securityContext
k explain pod.spec.containers.securityContext
```

------------------------------------------------------------------------------------------
## 3. Capabilities

Linux splits root's powers into ~40 capabilities: NET_BIND_SERVICE (use ports below
1024), NET_ADMIN (change network settings), SYS_TIME (change the clock), CHOWN, ...
`drop: ["ALL"]` removes them all. Names are written without the `CAP_` prefix.

------------------------------------------------------------------------------------------
## 4. Read-only root filesystem needs volumes

With `readOnlyRootFilesystem: true`, writing anywhere in the container fails with
"Read-only file system", and an app that writes logs or temp files crashes. Give it a
writable volume exactly where it writes:

```yaml
    volumeMounts:
    - name: tmp
      mountPath: /tmp               # this path is writable again
  volumes:                          # Pod level, next to containers
  - name: tmp
    emptyDir: {}                    # empty directory, lives as long as the Pod
```

------------------------------------------------------------------------------------------
## 5. Pod -> Deployment

Most Pod fields can't be changed after creation, and a bare Pod isn't restarted if its
node dies. A Deployment fixes both: it keeps N copies running and rolls out changes.

A Deployment wraps the Pod spec:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app            # must match the template labels below
  template:
    metadata:
      labels:
        app: app
    spec:                 # <- the Pod's spec: containers, volumes, securityContext
      containers: [...]
```

Workflow: `k create deploy <name> --image=<image> --replicas=3 $do > deploy.yaml`, then
copy the container details (name, command...) from the Pod manifest into the template,
add the extra fields, apply, and delete the old Pod.

Verify from inside: `k exec deploy/<name> -n <ns> -- id` prints the uid/gid/groups the
process runs with.

------------------------------------------------------------------------------------------
## 6. How this applies to question 9

  Task 1  Generate a Deployment, then copy the container from the Pod manifest exactly
          (same container name, image and command). Save it where the task says.
  Task 2  Sort each requested setting into Pod level or container level (section 2).
  Task 3  The root filesystem becomes read-only, but the app writes into /tmp: add an
          emptyDir volume and mount it there.
  Task 4  Delete the old bare Pod; only the Deployment's Pods should remain.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - fsGroup in the container's securityContext, or capabilities in the Pod's: the API
    rejects fields that don't exist at that level
  - Forgetting the emptyDir: the Pods crash with "Read-only file system"
  - `drop: ALL` written as a plain string instead of a list (`["ALL"]` or `- ALL`)
  - Changing the container name or command while converting
  - Leaving the original Pod running

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Configure a Security Context for a Pod or Container"   all fields + examples
  Search "Volumes" (emptyDir section)
  Search "Deployments"                                             the Deployment manifest

Now try it: ckad q 9
