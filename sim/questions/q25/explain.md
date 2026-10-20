# Lesson 25: Monitoring with kubectl top, and why containers restart

Curriculum: "Use built-in CLI tools to monitor Kubernetes applications" and "Debugging in
Kubernetes" (Application Observability and Maintenance, 15%).

------------------------------------------------------------------------------------------
## 1. The problem

"The node is slow and one app keeps restarting." Before fixing anything you need two
answers: who is using the CPU and memory right now, and why does the restarting container
die? kubectl answers both without extra tools.

------------------------------------------------------------------------------------------
## 2. kubectl top: live resource usage

`kubectl top` shows current CPU and memory usage. It reads from metrics-server, a small
add-on that collects usage from every node (it's installed in this lab and on the exam).

```bash
k top node                            # usage per node
k top pod -n demo                     # usage per Pod in a namespace
k top pod -A                          # all namespaces
k top pod -n demo --sort-by=cpu       # highest CPU first
k top pod -n demo --sort-by=memory    # highest memory first
k top pod <pod> -n demo --containers  # split by container
```

Reading the numbers:

  CPU     in millicores: 1000m = one full CPU core, 250m = a quarter of a core
  MEMORY  in Mi (mebibytes) or Gi

Notes:
  - The values are a snapshot, refreshed about every 15-60 seconds. A Pod that just
    started may not show up yet ("metrics not available yet"): wait a little.
  - `--sort-by` only accepts `cpu` or `memory`.
  - The first line after the header is the "top" Pod. To keep only the name:
        k top pod -n demo --sort-by=cpu --no-headers | head -1 | awk '{print $1}'

------------------------------------------------------------------------------------------
## 3. Container states and restarts

Every container is in one of three states:

  Waiting      not running yet (pulling the image, CrashLoopBackOff, ...)
  Running      running
  Terminated   exited, with an exit code and a REASON

When a container exits, the kubelet restarts it (Pods have `restartPolicy: Always` by
default). `k get pod` then shows the RESTARTS counter going up, and after repeated crashes
the status `CrashLoopBackOff`: Kubernetes waits longer and longer between restarts.

To find out WHY it died, look at the previous run:

```bash
k get pod <pod> -n demo                   # STATUS and RESTARTS
k describe pod <pod> -n demo              # look for "Last State:"
```

`describe` shows something like:

    State:          Running
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
    Restart Count:  4

Common reasons:

  OOMKilled            used more memory than its limit; the kernel killed it (exit 137)
  Error                the process exited with a non-zero code by itself
  Completed            the process exited with code 0 (normal for Jobs)
  StartError           the command couldn't be started, e.g. not found (exit 128)

Other useful commands:

```bash
k logs <pod> -n demo --previous      # output of the crashed run, not the current one
k get events -n demo                 # recent events in the namespace
```

Note for kubectl v1.37: `k describe` shows the Events section only when you describe ONE
object by name. With `-l` or several objects it's hidden; use `k get events` then.

------------------------------------------------------------------------------------------
## 4. Why a memory limit causes OOMKilled

A container can have a memory LIMIT (see `resources.limits.memory`). If the process uses
more, the kernel kills it immediately. There's no slowdown or warning, just exit code 137
and the reason OOMKilled. A CPU limit is different: going over it only slows the
container down (throttling); it never kills it.

```yaml
    resources:
      limits:
        memory: 16Mi        # using more than this -> OOMKilled
```

------------------------------------------------------------------------------------------
## 5. Writing a script that uses kubectl

A task may ask for a script file instead of an answer. The grader RUNS the script, so:
  - write the command into the file (`echo "..." > file.sh`, or vim)
  - use `kubectl`, not `k`: scripts don't see your shell aliases
  - test it: `bash file.sh` must print the expected output

------------------------------------------------------------------------------------------
## 6. How this applies to question 25

  Task 1  Sort the Pods in `lynx` by CPU; the name of the first one goes in the file.
  Task 2  Same, sorted by memory.
  Task 3  One kubectl command that shows usage for every node, written into the script.
          Run the script once to check it.
  Task 4  `describe` the restarting Pod and read the Reason under "Last State". Write
          that one word, exactly as shown (case matters).

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Writing `k` instead of `kubectl` in the script
  - Running `k top pod` without `-n lynx`, and picking a Pod from another namespace
  - Reading "State" instead of "Last State": the current state is usually Running or
    Waiting, the reason for the crash is under Last State
  - Writing "OOMKILLED" or "oom killed": copy the reason exactly
  - Giving up when metrics aren't ready yet: give metrics-server a minute

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "kubectl top"                         command reference and flags
  Search "Resource metrics pipeline"           how metrics-server works
  Search "Pod Lifecycle"                       container states and restart policy
  Search "Assign Memory Resources to Containers"   memory limits and OOMKilled

See also: ckad explain 7 (debugging a crash), ckad explain 42 (requests and limits)

Now try it: ckad q 25
