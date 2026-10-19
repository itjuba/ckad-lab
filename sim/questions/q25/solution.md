# Solution 25

`kubectl top` reads from metrics-server and can sort for you:

```bash
k top pod -n lynx --sort-by=cpu        # first line = highest CPU
k top pod -n lynx --sort-by=memory     # first line = highest memory

echo <crunch-pod-name> > /opt/course/25/top-cpu
echo <hoard-pod-name>  > /opt/course/25/top-mem

echo "kubectl top node" > /opt/course/25/node-usage.sh
bash /opt/course/25/node-usage.sh
```

The restarting Pod:

```bash
k get pod lynx-flaky -n lynx                 # RESTARTS keeps growing
k describe pod lynx-flaky -n lynx            # Last State: Terminated, Reason: OOMKilled

echo OOMKilled > /opt/course/25/flaky-reason
```

Remember:
- `k describe` shows **Last State** with the reason and exit code. `OOMKilled` (exit
  code 137) means the container hit its memory limit.
- `k logs <pod> --previous` shows the output of the crashed container, not the restarted one.
- `--sort-by` only takes `cpu` or `memory`.
