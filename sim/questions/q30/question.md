# Container logs and exec

Namespace: `fornax`

Team Fornax runs two Pods in Namespace `fornax`: `fornax-app`, which has more than one
container, and `fornax-worker`, which crashed and was restarted.

1. Write the **last 5 lines** of the logs of the `logger` container of Pod `fornax-app`
   into `/opt/course/30/logger.log`.

2. Pod `fornax-worker` has restarted. Write the logs of its **previous** (crashed) run
   into `/opt/course/30/worker-previous.log`.

3. Run `nginx -v` inside the `web` container of Pod `fornax-app` and write its output
   into `/opt/course/30/nginx-version`.

4. Write the names of all containers of Pod `fornax-app`, one per line, into
   `/opt/course/30/containers`.
