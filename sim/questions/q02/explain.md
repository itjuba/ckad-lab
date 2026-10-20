# Lesson 2: Pods, containers and container ports

Curriculum: the foundation of every domain; this question sits in Application Design and
Build (20%). Almost every CKAD task creates or changes a Pod, directly or through a
Deployment or Job.

------------------------------------------------------------------------------------------
## 1. What a Pod is

A Pod is the smallest thing Kubernetes runs: one or more containers that share an IP
address and can share volumes. Kubernetes doesn't run containers directly; it runs Pods.

  - Each Pod gets its own IP address (it changes when the Pod is recreated)
  - Usually one container per Pod; extra containers are "sidecars" (see lessons 16, 36)
  - Pods are disposable. Deployments/Jobs create them for you; a bare Pod that dies is gone

------------------------------------------------------------------------------------------
## 2. The Pod manifest, line by line

```yaml
apiVersion: v1              # API version for Pods
kind: Pod
metadata:
  name: lyra-web            # the Pod's name
  namespace: lyra
  labels:
    run: lyra-web           # kubectl run adds run=<name> by default
spec:
  containers:               # a LIST: each "- name:" is one container
  - name: lyra-web          # the CONTAINER's name (kubectl run copies the Pod name)
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80     # the port the app listens on
      name: http            # optional name for that port
```

Every object has the same four top-level parts: apiVersion, kind, metadata, spec.

Port names matter later: a Service can target `http` instead of `80` (lesson 10), and a
probe can check `port: http` (lesson 6). Rules for port names: lowercase letters, digits
and `-`, at most 15 characters.

------------------------------------------------------------------------------------------
## 3. Creating Pods: kubectl run

```bash
k run web --image=nginx:1.29-alpine                       # create it now
k run web --image=nginx:1.29-alpine -n lyra --port=80     # with a container port
k run web --image=nginx:1.29-alpine -l app=web,team=x     # with labels
k run web --image=nginx:1.29-alpine --env=MODE=prod       # with an env var
k run web --image=busybox:1.37 -- sleep 3600              # args after --
k run web --image=nginx:1.29-alpine $do > web.yaml        # only write YAML
```

`kubectl run` can't set everything. It can't rename the container or name a port, add
probes, volumes, securityContext... For those: generate YAML with `$do`, edit it in vim,
then `k apply -f web.yaml`. That "generate, edit, apply" loop is the core exam skill.

`k explain` shows which fields exist, without leaving the terminal:

```bash
k explain pod.spec.containers.ports      # containerPort, name, protocol...
```

------------------------------------------------------------------------------------------
## 4. Looking at Pods

```bash
k get pod lyra-web -n lyra               # STATUS, RESTARTS, AGE
k get pod lyra-web -n lyra -o wide       # + IP and NODE
k describe pod lyra-web -n lyra          # everything, with Events at the bottom
```

Pod STATUS you'll meet: Pending (not scheduled yet), ContainerCreating, Running,
Completed, Error, CrashLoopBackOff (keeps crashing), ImagePullBackOff (bad image name).

Most Pod fields can't be changed after creation (image is one of the few that can). To
change a container name or port: edit your YAML, then delete and recreate, or use
`k replace --force -f web.yaml` which does both.

------------------------------------------------------------------------------------------
## 5. Scripts that print one value

Some tasks ask for a script that prints exactly one thing. Rules:

  - Use `kubectl`, not `k`: scripts don't load your shell aliases
  - Print ONLY the value: no header, no other columns
  - Test it: `bash /path/script.sh`

Picking one column from a table works with `--no-headers` and `awk`:

```bash
kubectl get pod web -o wide --no-headers                    # one line, no header
kubectl get pod web -o wide --no-headers | awk '{print $6}' # 6th column only
```

Write the script with vim. With `echo "... $6 ..."`, the shell would replace `$6` with
nothing before it reaches the file.

------------------------------------------------------------------------------------------
## 6. How this applies to question 2

  Task 1  `kubectl run` gets you the image and the port number, but the container name
          and the port name need editing. Generate YAML, fix those two things, apply.
  Task 2  Look at the -o wide output to see which column holds the IP. Put a kubectl
          command that prints only that column into the script, then run the script to
          check it prints just the IP.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Leaving the container name as the Pod name (kubectl run's default)
  - `name: http` at the wrong indentation: it belongs to the same port entry as
    `containerPort` (same `- ` list item)
  - Using `k` inside the script
  - A script that prints the whole table row instead of only the IP
  - Creating the Pod in `default` because `-n lyra` was forgotten

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Pods"                       what Pods are, example manifest
  Search "kubectl run"                every flag of kubectl run
  Search "kubectl Quick Reference"    output formats

See also: ckad explain 29 (command, args and env vars), ckad explain 10 (named ports)

Now try it: ckad q 2
