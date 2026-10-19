# Solution 29

`kubectl run` sets labels and env vars. Everything after `--` becomes the container's
`args`, and `--command` turns it into `command` instead. Generate YAML and split it by hand:

```bash
k run greeter -n mensa --image=busybox:1.37 -l team=mensa \
  --env=GREETING=hello --env=TARGET=ckad $do \
  --command -- sh -c 'echo "$GREETING, $TARGET"; sleep 3600' > 29.yaml
vim 29.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: greeter
  namespace: mensa
  labels:
    team: mensa
spec:
  containers:
  - name: greeter
    image: busybox:1.37
    env:
    - name: GREETING
      value: hello
    - name: TARGET
      value: ckad
    command: ["sh", "-c"]                              # only the shell
    args: ['echo "$GREETING, $TARGET"; sleep 3600']    # moved here from command
```

```bash
k apply -f 29.yaml
k get pod greeter -n mensa

k logs greeter -n mensa > /opt/course/29/greeting.log                  # hello, ckad
k exec greeter -n mensa -- printenv TARGET > /opt/course/29/target    # ckad
```

Remember:
- `command` replaces the image's ENTRYPOINT and `args` replaces its CMD. `-- <cmd>` alone
  sets `args`, and `--command -- <cmd>` sets `command`.
- Use single quotes around the script, so your own shell doesn't expand `$GREETING`
  while you type the command.
- `k exec <pod> -- <cmd>` runs one command in the container. Add `-c <name>` when the
  Pod has several containers.
