# Unreachable Service, then expose it on a NodePort

Namespace: `columba`

Team Columba deployed their website, but nobody can reach it through the Service
`columba-web`.

1. Find out why the Service `columba-web` doesn't send traffic to the Pods of the
   Deployment `columba-web` and fix it. Don't change the Deployment.
   Write the cause in one line to `/opt/course/27/cause`.

2. Make the Service reachable from outside the cluster on every node at port `30780`.

3. From the terminal, request the website through that node port on node
   `k3d-ckad-server-0` and save the response to `/opt/course/27/nodeport.html`.
