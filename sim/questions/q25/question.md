# Resource monitoring and a restarting Pod

Namespace: `lynx`

Team Lynx says something in their namespace is eating the node's resources, and one Pod
keeps restarting. Use the cluster's built-in tools to find out what's going on.

1. Write the name of the Pod in `lynx` that currently uses the most **CPU** into
   `/opt/course/25/top-cpu`.

2. Write the name of the Pod in `lynx` that currently uses the most **memory** into
   `/opt/course/25/top-mem`.

3. Write a script `/opt/course/25/node-usage.sh` that shows the current CPU and memory
   usage of every node, using `kubectl`.

4. The Pod `lynx-flaky` keeps restarting. Write the reason Kubernetes gives for the last
   termination of its container (one word, exactly as Kubernetes reports it) into
   `/opt/course/25/flaky-reason`.
