# Solution 37

`--from-file` with a file creates one key named after the file. Passing the whole folder
would include `notes.txt` too, so list the two files:

```bash
cd /opt/course/37/config
k create configmap crater-config -n crater --from-file=app.properties --from-file=logging.properties
k describe cm crater-config -n crater          # two keys, no notes.txt
```

Generate the Pod and add two volumes from the same ConfigMap (docs search: "configure pod
configmap", section "Add ConfigMap data to a specific path in the Volume"):

```bash
k run crater-app -n crater --image=busybox:1.37 $do --command -- sleep 1d > 37.yaml
vim 37.yaml
```

```yaml
spec:
  volumes:                              # added
  - name: config
    configMap:
      name: crater-config               # all keys become files
  - name: logging
    configMap:
      name: crater-config
      items:                            # only this key...
      - key: logging.properties
        path: log.conf                  # ...under this file name
  containers:
  - name: crater-app
    image: busybox:1.37
    command: ["sleep", "1d"]
    volumeMounts:                       # added
    - name: config
      mountPath: /etc/crater
      readOnly: true
    - name: logging
      mountPath: /etc/logging
```

```bash
k apply -f 37.yaml
k exec crater-app -n crater -- ls /etc/crater /etc/logging
k exec crater-app -n crater -- cat /etc/crater/app.properties > /opt/course/37/app.properties.out
```

Remember:
- `--from-file=<folder>` takes every file in the folder. Use one `--from-file=<file>` per file
  when only some should go in.
- `items` limits which keys are mounted and lets you rename them (`path`). Keys you don't list
  aren't mounted at all.
- Mounting a volume on a folder hides whatever the image had there. Mounting a single file with
  `subPath: logging.properties` and `mountPath: /etc/logging/log.conf` also works, but
  `subPath` mounts don't receive ConfigMap updates.
