# Solution 35

Generate the Pod, then add the volume and the init container. The docs page
"init containers" has an example to copy from.

```bash
k run lacerta-web -n lacerta --image=nginx:1.29-alpine $do > 35.yaml
vim 35.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lacerta-web
  namespace: lacerta
spec:
  volumes:                              # added
  - name: content
    emptyDir: {}
  initContainers:                       # added: runs to completion before "web" starts
  - name: fetch
    image: busybox:1.37
    command: ["sh", "-c", "echo '<h1>Lacerta</h1>' > /work/index.html"]
    volumeMounts:
    - name: content
      mountPath: /work
  containers:
  - name: web                           # was: lacerta-web
    image: nginx:1.29-alpine
    volumeMounts:                       # added
    - name: content
      mountPath: /usr/share/nginx/html
```

```bash
k apply -f 35.yaml
k get pod lacerta-web -n lacerta -o wide        # STATUS Init:0/1, then Running; note the IP

k run tmp -n lacerta --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://<pod-ip> > /opt/course/35/index.html
cat /opt/course/35/index.html                   # <h1>Lacerta</h1>
k get pod -n lacerta                            # only lacerta-web is left
```

Remember:
- Init containers run one after another and must exit successfully before the main containers
  start. While they run, the Pod shows `Init:0/1`.
- Both containers see the same files because they mount the same volume. The mount paths can
  differ (`/work` vs `/usr/share/nginx/html`).
- `--rm -i` deletes the temporary Pod as soon as the command finishes. If the output ends with
  `pod "tmp" deleted`, remove that line from the file.
