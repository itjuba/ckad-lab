# Solution 2

`kubectl run` can't name a port or a container, so generate YAML and edit it:

```bash
k run lyra-web -n lyra --image=httpd:2.4-alpine --port=80 $do > 2.yaml
vim 2.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lyra-web
  namespace: lyra
spec:
  containers:
  - name: lyra-web-container      # was: lyra-web
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
      name: http                  # added
```

```bash
k apply -f 2.yaml
k get pod lyra-web -n lyra -o wide                     # IP is the 6th column

echo "kubectl get pod lyra-web -n lyra -o wide --no-headers | awk '{print \$6}'" > /opt/course/2/pod-ip.sh
bash /opt/course/2/pod-ip.sh
```

Scripts don't load your shell aliases, so `k` would fail inside `pod-ip.sh`.

The `\$6` keeps the shell from expanding `$6` while `echo` writes the file. If the Pod
had restarted, RESTARTS would read `1 (2m ago)` and shift the columns. A version that
doesn't depend on column order:
`kubectl get pod lyra-web -n lyra -o custom-columns=IP:.status.podIP --no-headers`.
