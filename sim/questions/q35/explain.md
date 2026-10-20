# Lesson 35: Init containers and shared emptyDir volumes

Curriculum: "Understand multi-container Pod design patterns (e.g. sidecar, init and
others)" and "Utilize persistent and ephemeral volumes" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem

Often something has to happen BEFORE your app starts: download a file, generate a config,
wait for a database, set permissions. You don't want to put those tools into the app image.

An init container is a container that runs first, to completion, and then gets out of the
way. Only when every init container has exited successfully do the normal containers start.

    Pod starts -> init container 1 -> init container 2 -> ... -> main containers run

------------------------------------------------------------------------------------------
## 2. How the init container hands over its work: a shared volume

Containers in a Pod don't share a filesystem by default. To pass files from the init
container to the main container, both mount the same volume. An `emptyDir` is the
simplest volume: an empty folder created when the Pod starts and deleted with the Pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: site
spec:
  volumes:                         # 1. declare the volume once, at Pod level
  - name: html
    emptyDir: {}                   #    {} = an empty folder, no options
  initContainers:                  # 2. runs first, must exit 0
  - name: generate
    image: busybox:1.37
    command: ["sh", "-c", "echo '<p>generated at start</p>' > /out/index.html"]
    volumeMounts:
    - name: html                   #    same volume...
      mountPath: /out              #    ...seen here as /out
  containers:                      # 3. starts after all init containers succeeded
  - name: web
    image: nginx:1.29-alpine
    volumeMounts:
    - name: html                   #    same volume...
      mountPath: /usr/share/nginx/html   # ...seen here, where nginx serves files from
```

Key points:

  - `volumes` is a Pod-level list. `volumeMounts` is per container.
  - The volume NAME connects them. The mount PATHS can be different in each container.
  - Mounting a volume on a folder hides what the image had there. Here nginx's default
    page is replaced by whatever the init container wrote.
  - `initContainers` sits next to `containers`, at the same indentation.

------------------------------------------------------------------------------------------
## 3. What you see while it starts

```bash
k get pod site -n <ns>
#   STATUS Init:0/1        the init container is running
#   STATUS PodInitializing init done, main containers starting
#   STATUS Running         done
#   STATUS Init:Error / Init:CrashLoopBackOff   the init container failed
k logs site -c generate -n <ns>        # logs of the init container
k describe pod site -n <ns>            # "Init Containers:" section, state and exit code
```

------------------------------------------------------------------------------------------
## 4. Commands

There's no kubectl flag for init containers or volumes, so generate the Pod and add them:

```bash
k run site -n <ns> --image=nginx:1.29-alpine $do > pod.yaml
vim pod.yaml          # add volumes, initContainers, volumeMounts; rename the container
k apply -f pod.yaml
k get pod site -n <ns> -o wide         # note the Pod IP

# test from another Pod with a temporary busybox (wget is built in)
k run tmp -n <ns> --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://<pod-ip>

k explain pod.spec.initContainers      # field documentation
```

`--rm -i` attaches to the temporary Pod, prints its output, and deletes it when the
command ends. Its output can be redirected into a file with `>` like any command. If
`pod "tmp" deleted` ends up in the file, remove that line.

------------------------------------------------------------------------------------------
## 5. How this applies to question 35

  Task 1  Generate the Pod with `k run ... $do` and add an emptyDir volume with the given
          name.
  Task 2  Add an `initContainers` entry with the given name and image. It mounts the
          volume at /work, and its command writes the HTML line into a file there (a
          `sh -c` with `echo ... >`).
  Task 3  Rename the main container to the required name and mount the same volume where
          nginx serves its pages.
  Task 4  Find the Pod IP (`-o wide`), fetch it from a temporary busybox Pod in the same
          namespace, save the output, and make sure no temporary Pod is left.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Putting `initContainers` inside `containers`, or at the wrong indentation
  - Different volume names in `volumes` and `volumeMounts`: the Pod won't be created
  - Forgetting to mount the volume in the main container: nginx serves its default page
  - Quoting: the HTML contains `<` and `>`, so the whole script must be in quotes, for
    example `["sh", "-c", "echo '<h1>Hi</h1>' > /work/index.html"]`
  - Keeping the generated container name (the Pod name) instead of the required one
  - Leaving the temporary Pod behind: use `--rm`, or delete it afterwards

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Init Containers"                   concept page with a full example
  Search "Configure a Pod to Use a Volume for Storage"   emptyDir example
  Search "Volumes", section "emptyDir"

See also: ckad explain 24 (DaemonSet with an init container), ckad explain 36 (two
containers sharing a volume)

Now try it: ckad q 35
