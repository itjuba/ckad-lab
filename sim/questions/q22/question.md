# Canary release behind an existing Service

Namespace: `castor`

Deployment `castor-v1` (4 replicas) serves traffic through Service `castor`.
Team Castor wants to try a new version on a small share of real traffic before
switching over.

1. Create Deployment `castor-v2`:
   - image `traefik/whoami:v1.11`, container argument `--name=v2`
   - Pod labels `app=castor` and `version=v2`

   Service `castor` must send traffic to the new Pods too. **Do not change the Service.**

2. Keep 4 Pods in total behind the Service, with 25% of them running v2.

3. From a temporary Pod, call the Service 20 times. Write the `Name:` line of
   each response into `/opt/course/22/responses`. The file must show both
   `Name: v1` and `Name: v2`.
