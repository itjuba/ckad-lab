# ConfigMap mounted as files

Namespace: `crater`

Team Crater keeps its configuration files in `/opt/course/37/config/`.

1. Create a ConfigMap `crater-config` in Namespace `crater` from **only** the files
   `app.properties` and `logging.properties` in that folder. Each file becomes one key, named
   after the file. `notes.txt` must not end up in the ConfigMap.

2. Create a Pod `crater-app` in `crater` (image `busybox:1.37`, command `sleep 1d`) that
   mounts:
   - the whole ConfigMap at `/etc/crater`, with `readOnly: true`
   - only the key `logging.properties`, as the file `/etc/logging/log.conf`

3. Run `cat /etc/crater/app.properties` in the Pod and write the output to
   `/opt/course/37/app.properties.out`.
