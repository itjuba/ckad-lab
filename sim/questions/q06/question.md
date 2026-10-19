# Readiness and liveness probes

Namespace: `hydra`

Team Hydra wants Kubernetes to know when its web servers are healthy.

1. Create a Pod named `heartbeat` in Namespace `hydra` with image
   `nginx:1.29-alpine`, and configure:
   - a **readiness** probe that sends an HTTP GET to path `/` on port `80`,
     starting after 5 seconds and repeating every 10 seconds
   - a **liveness** probe that opens a TCP connection to port `80`, starting
     after 10 seconds, repeating every 20 seconds, and failing after 3 attempts

   The Pod must become Ready.

2. The Pods of the existing Deployment `hydra-api` keep restarting and never
   become Ready. Find out why and fix the Deployment so its rollout completes.
   Don't change the container image.
