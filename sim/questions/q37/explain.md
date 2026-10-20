# Lesson 37: ConfigMaps mounted as files

Curriculum: "Understand ConfigMaps" (Application Environment, Configuration and Security,
25%) and "Utilize persistent and ephemeral volumes" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem

Apps need configuration: a port, a log level, a whole properties file. Baking it into the
image means rebuilding the image for every change and every environment (dev, prod).

A ConfigMap stores configuration in the cluster, separate from the image. Pods read it
either as environment variables or as files.

------------------------------------------------------------------------------------------
## 2. What a ConfigMap looks like

A ConfigMap is a set of keys. Each value is a string, which can be a whole file:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: shop-config
data:
  shop.properties: |          # key = a file name, value = the file content
    currency=EUR
    tax=0.2
  theme: dark                 # key = a short value
```

------------------------------------------------------------------------------------------
## 3. Creating one: the from-file variants

```bash
k create configmap shop-config --from-literal=theme=dark       # key=value typed inline
k create configmap shop-config --from-file=shop.properties     # key = file name
k create configmap shop-config --from-file=conf=shop.properties  # key = "conf" (renamed)
k create configmap shop-config --from-file=./config/           # EVERY file in the folder
k create configmap shop-config --from-env-file=app.env         # each KEY=value LINE = a key
```

Flags can be repeated: `--from-file=a.properties --from-file=b.properties` gives two keys.
Check the result with `k describe cm shop-config` (shows keys and values).

------------------------------------------------------------------------------------------
## 4. Mounting it as files

A volume of type `configMap` turns each key into a file:

```yaml
spec:
  volumes:
  - name: config                    # whole ConfigMap: every key becomes a file
    configMap:
      name: shop-config
  - name: theme-only                # only some keys, optionally renamed
    configMap:
      name: shop-config
      items:
      - key: theme                  # which key...
        path: ui-theme.txt          # ...and the file name to use for it
  containers:
  - name: app
    image: busybox:1.37
    command: ["sleep", "1d"]
    volumeMounts:
    - name: config
      mountPath: /etc/shop          # -> /etc/shop/shop.properties and /etc/shop/theme
      readOnly: true                # the app can't write here
    - name: theme-only
      mountPath: /etc/ui            # -> only /etc/ui/ui-theme.txt
```

  - Without `items`: all keys become files, named after the keys.
  - With `items`: ONLY the listed keys are mounted, under the `path` you choose.
  - The same ConfigMap can back several volumes, each with its own `items`.
  - Mounting on a folder hides whatever the image had in that folder.
  - Files from a configMap volume are updated (after a short delay) when the ConfigMap
    changes. Environment variables are not.

Mounting one key as one single file into an existing folder uses `subPath`:

```yaml
    - name: config
      mountPath: /etc/nginx/conf.d/shop.conf   # a FILE path
      subPath: shop.properties                 # the key to put there
```

`subPath` mounts don't receive updates.

------------------------------------------------------------------------------------------
## 5. Checking from inside the Pod

```bash
k exec <pod> -n <ns> -- ls /etc/shop                  # which files exist
k exec <pod> -n <ns> -- cat /etc/shop/shop.properties # content of one
k explain pod.spec.volumes.configMap.items            # field documentation
```

------------------------------------------------------------------------------------------
## 6. How this applies to question 37

  Task 1  The folder has three files but only two may go in. `--from-file=<folder>` would
          take all three, so pass the two files one by one. Check the keys with describe.
  Task 2  Generate the Pod with `k run ... $do --command -- sleep 1d`, then add TWO volumes
          from the same ConfigMap: one for the whole map, one with `items` that maps the
          single key to the required file name. Mount them at the two paths, with
          readOnly on the first one.
  Task 3  `exec` the cat command in the Pod and redirect the output to the file.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - `--from-file=<folder>`: picks up files that shouldn't be there
  - `items.path` with a folder or a leading `/`: it's just the file name, relative to the
    mountPath. The folder comes from `mountPath`
  - Mounting the second volume at the full file path (`/etc/logging/log.conf`) without
    subPath: Kubernetes then creates a FOLDER with that name
  - Forgetting `readOnly: true` when the task asks for it
  - Two volumes with the same name: each volume needs its own name
  - Typos in the key name under `items`: the Pod fails to start (ContainerCreating with a
    volume error in describe)

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Configure a Pod to Use a ConfigMap"   sections "Create a ConfigMap",
                                                "Add ConfigMap data to a Volume" and
                                                "Add ConfigMap data to a specific path"
  Search "ConfigMaps"                           concept page

See also: ckad explain 15 (ConfigMap as environment variables), ckad explain 14 and 38
(Secrets work the same way)

Now try it: ckad q 37
