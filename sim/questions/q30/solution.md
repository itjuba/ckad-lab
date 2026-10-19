# Solution 30

```bash
# 4. which containers does the Pod have? (READY 2/2 means two)
k get pod -n fornax
k describe pod fornax-app -n fornax | less        # /Containers, then read the names: web, logger
printf 'web\nlogger\n' > /opt/course/30/containers

# 1. -c picks the container, --tail limits the lines
k logs fornax-app -n fornax -c logger --tail=5 > /opt/course/30/logger.log

# 2. --previous (-p) shows the run before the last restart
k get pod fornax-worker -n fornax                 # RESTARTS 1
k logs fornax-worker -n fornax --previous > /opt/course/30/worker-previous.log

# 3. nginx -v prints to stderr, so redirect stderr too
k exec fornax-app -n fornax -c web -- nginx -v > /opt/course/30/nginx-version 2>&1
cat /opt/course/30/nginx-version                  # nginx version: nginx/1.29.x
```

Remember:
- With several containers, `k logs` and `k exec` need `-c <container>`. Without it,
  kubectl uses the default container and prints a note on which one it picked.
- `--previous` is how you read why a container crashed. The current run's logs only show
  what happened after the restart.
- `> file` captures only stdout. Add `2>&1` when a command writes to stderr (`nginx -v`,
  many `--version` flags, error messages). If the file is empty, that's the reason.
