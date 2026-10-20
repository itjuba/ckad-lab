# Lesson 36: Multi-container Pods sharing a volume

Curriculum: "Understand multi-container Pod design patterns (e.g. sidecar, init and
others)" and "Utilize persistent and ephemeral volumes" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem

One app writes a log file. Another process should read it live: ship it to a log system,
or reformat it. Both must see the same file, and they belong together (start, stop and
scale as one unit).

That's what a Pod with several containers is for. Containers in one Pod:

  - are scheduled together on the same node
  - share the network: they reach each other on `localhost`
  - can share files, but only through a volume both of them mount

Common patterns: a sidecar (log shipper, proxy) next to the main app, an adapter that
converts output, an ambassador that proxies connections.

------------------------------------------------------------------------------------------
## 2. How it works

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-reader
spec:
  volumes:
  - name: logs                     # one volume, declared at Pod level
    emptyDir: {}
  containers:                      # a LIST: each "- name:" is one container
  - name: app
    image: busybox:1.37
    command: ["sh", "-c", "while true; do echo tick >> /var/log/app.log; sleep 5; done"]
    volumeMounts:
    - name: logs
      mountPath: /var/log          # app writes here
  - name: reader
    image: busybox:1.37
    command: ["tail", "-F", "/data/app.log"]
    volumeMounts:
    - name: logs                   # same volume name = same files
      mountPath: /data             # different path is fine
```

  - `tail -F` keeps following the file and waits if it doesn't exist yet. What it reads it
    prints to stdout, so it shows up in `k logs ... -c reader`.
  - `while true; do ...; sleep 5; done` is the usual shell loop for "do this forever".
  - `READY 2/2` in `k get pod` means both containers are running.

------------------------------------------------------------------------------------------
## 3. Working with one container of a multi-container Pod

With more than one container, tell kubectl which one you mean with `-c`:

```bash
k logs app-with-reader -c reader -n <ns>          # logs of one container
k logs app-with-reader --all-containers -n <ns>   # all of them
k exec app-with-reader -c reader -n <ns> -- ls /data
k exec -it app-with-reader -c app -n <ns> -- sh   # interactive shell, exit to leave
k describe pod app-with-reader -n <ns>            # the "Containers:" section lists names
```

Without `-c`, kubectl uses the first (default) container and prints a note about it.

------------------------------------------------------------------------------------------
## 4. Generating the YAML

```bash
k run app-with-reader -n <ns> --image=busybox:1.37 $do --command \
  -- sh -c 'while true; do echo tick >> /var/log/app.log; sleep 5; done' > pod.yaml
vim pod.yaml
#   rename the container, add volumeMounts,
#   copy the container block (yy / p in vim) for the second container and change it,
#   add the volumes list at Pod level
k apply -f pod.yaml
```

`--command` makes the part after `--` the container's `command`. Without it, it becomes
`args`. Both work for busybox, but `command` is what you usually mean.

------------------------------------------------------------------------------------------
## 5. Regular containers vs native sidecars

  Regular second container (this lesson)    starts together with the others, no order
  Native sidecar (question 16)              an init container with restartPolicy: Always.
                                            Starts BEFORE the main containers, keeps
                                            running, stops AFTER them

Both share volumes the same way. Use a native sidecar when the order matters, for
example a log shipper that must not miss the first lines.

------------------------------------------------------------------------------------------
## 6. How this applies to question 36

  Task 1  Generate a busybox Pod, then turn it into two containers with the exact names,
          images and commands from the question. Both mount the same emptyDir at /shared.
          Check for READY 2/2.
  Task 2  Save the logs of the reading container (`-c`), after a few seconds so they
          contain lines.
  Task 3  Run `ls /shared` inside the reading container with `exec -c ... --` and save the
          output.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Forgetting `-c`: logs or exec go to the wrong container
  - The second container indented wrongly, so it's not part of the `containers` list
  - Two containers with the same name: names must be unique in a Pod
  - Mounting the volume in only one container: the other sees an empty or missing folder
  - Writing `>` instead of `>>` in the loop: the file is overwritten every time
  - Saving the logs immediately, before the first line was written

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Communicate Between Containers in the Same Pod Using a Shared Volume"
  Search "Sidecar Containers"        native sidecars
  Search "Pods", section "How Pods manage multiple containers"

See also: ckad explain 16 (native sidecar), ckad explain 35 (init container)

Now try it: ckad q 36
