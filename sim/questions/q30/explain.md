# Lesson 30: Container logs and kubectl exec

Curriculum: "Utilize container logs" and "Debugging in Kubernetes" (Application
Observability and Maintenance, 15%).

------------------------------------------------------------------------------------------
## 1. Where logs come from

A container's logs are everything its main process writes to stdout and stderr.
Kubernetes stores them on the node, and `kubectl logs` fetches them. If an app writes
only to a file inside the container, `kubectl logs` shows nothing (that's what sidecars
are for, see lesson 16).

Logs belong to a CONTAINER, not a Pod. In a Pod with several containers, each one has its
own logs.

------------------------------------------------------------------------------------------
## 2. kubectl logs, flag by flag

```bash
k logs web -n demo                    # all logs of the Pod's (only) container
k logs web -n demo -c sidecar         # pick a container (-c / --container)
k logs web -n demo --all-containers   # every container, one after another
k logs web -n demo --tail=20          # only the last 20 lines
k logs web -n demo --since=10m        # only the last 10 minutes
k logs web -n demo -f                 # follow live (Ctrl+C to stop)
k logs web -n demo -p                 # --previous: the run BEFORE the last restart
k logs deploy/web -n demo             # one Pod of a Deployment, picked for you
k logs job/backup -n demo             # one Pod of a Job
```

With several containers and no `-c`, kubectl uses the default container and prints
`Defaulted container "..." out of: ...`. Always use `-c` when a Pod has more than one
container.

------------------------------------------------------------------------------------------
## 3. --previous: why did it crash?

When a container crashes and restarts, `k logs` shows the NEW run, which usually just
started and says nothing useful. The crash message is in the previous run:

```bash
k get pod worker -n demo              # RESTARTS greater than 0
k logs worker -n demo --previous      # what the crashed run printed before it died
k describe pod worker -n demo         # "Last State: Terminated", Reason, Exit Code
```

Kubernetes keeps only the most recent dead container, so `--previous` shows exactly one
earlier run.

------------------------------------------------------------------------------------------
## 4. Which containers does a Pod have?

```bash
k get pod web -n demo                 # READY 2/2 = two containers
k describe pod web -n demo | less     # type /Containers, the names are listed below it
k get pod web -n demo -o yaml | grep -e "- name:" -e "image:"
```

kubectl also tells you the names in its messages:
    Defaulted container "web" out of: web, logger            (no -c given)
    error: container xyz is not valid for pod demo out of: web, logger

------------------------------------------------------------------------------------------
## 5. kubectl exec: running a command inside a container

```bash
k exec web -n demo -- ls /etc                  # one command, output to your terminal
k exec web -n demo -c sidecar -- cat /tmp/x    # in a specific container
k exec -it web -n demo -- sh                   # interactive shell (type exit to leave)
```

  `--`   separates kubectl's flags from the command run in the container
  `-it`  interactive + terminal: only for shells, never when redirecting to a file

------------------------------------------------------------------------------------------
## 6. stdout, stderr and saving to files

Programs have two output streams:

  stdout (1)   normal output
  stderr (2)   errors and diagnostics, and some programs print version info here

`> file` captures only stdout. If a command prints to stderr, the file stays EMPTY and the
text appears on your screen instead. Add `2>&1` to send stderr to the same place:

```bash
k exec web -n demo -- nginx -v > version.txt          # empty file! nginx -v uses stderr
k exec web -n demo -- nginx -v > version.txt 2>&1     # captured
```

Rule of thumb: if the text appeared on screen although you redirected it, it was stderr.

Writing several lines into a file by hand:

```bash
printf 'first\nsecond\n' > file       # \n = new line
vim file                              # or just type them in vim
```

------------------------------------------------------------------------------------------
## 7. How this applies to question 30

  Task 1  The logs of one specific container, limited to the last lines asked for.
  Task 2  `fornax-worker` has restarted: you want the run before the restart.
  Task 3  `k exec` into the right container. Check the file afterwards: is it empty?
  Task 4  Find the container names, then write them one per line.

------------------------------------------------------------------------------------------
## 8. Common mistakes

  - Forgetting `-c` in a multi-container Pod: you get the wrong container's logs
  - Reading the current run instead of `--previous` for a crash
  - An empty file from a command that prints to stderr: add `2>&1`
  - Using `-it` together with `> file`: the file gets terminal control characters
  - `--tail 5` counts lines from the END; `head` would give the first lines instead

------------------------------------------------------------------------------------------
## 9. Docs (kubernetes.io)

  Search "kubectl logs"                       all flags
  Search "Get a Shell to a Running Container" kubectl exec examples
  Search "Debug Running Pods"                 logs, exec and describe together

See also: ckad explain 7 (debugging a crash), ckad explain 36 (two containers in a Pod)

Now try it: ckad q 30
