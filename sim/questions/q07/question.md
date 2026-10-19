# Debug a crashing workload

Namespace: `cygnus`

Users report that Team Cygnus's queue processing has stopped. One of the
Deployments in Namespace `cygnus` has Pods that keep crashing.

1. Write the name of that Deployment into `/opt/course/7/broken-deployment`.

2. Write the error line its container logs before it exits into
   `/opt/course/7/error.log`.

3. Fix the Deployment. The value it needs already exists under key `queue.url`
   in ConfigMap `cygnus-config`. Provide it to the container from that
   ConfigMap (don't copy the value into the Deployment). Afterwards the
   Deployment's Pods must run without crashing.
