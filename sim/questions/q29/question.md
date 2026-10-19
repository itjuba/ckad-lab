# Pod with command, args and env vars

Namespace: `mensa`

Team Mensa wants a small greeter Pod whose message comes from environment variables.

1. Create a Pod named `greeter` in Namespace `mensa`:
   - image `busybox:1.37`, container name `greeter`
   - label `team=mensa`
   - environment variables `GREETING=hello` and `TARGET=ckad`
   - set the container's `command` to `["sh", "-c"]` and put the script in `args`:
     `echo "$GREETING, $TARGET"; sleep 3600`

2. Write the Pod's logs into `/opt/course/29/greeting.log`.

3. Run `printenv TARGET` inside the container and write its output into
   `/opt/course/29/target`.
