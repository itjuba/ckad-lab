# Deployment basics: create, scale, update, expose

Namespace: `octans`

Team Octans needs its first Deployment.

1. Create a Deployment `octans-web` in Namespace `octans`:
   - image `nginx:1.28-alpine`, **2** replicas
   - Pod label `app=octans-web` (what `kubectl create deployment` sets by default)
   - container port `80`

2. Scale it to **4** replicas.

3. Update the image to `nginx:1.29-alpine` and wait until the rollout is finished.

4. Write the output of `kubectl rollout history` for this Deployment into
   `/opt/course/31/history`. It must show at least 2 revisions.

5. Expose the Deployment with a ClusterIP Service `octans-web` on port `8080`, forwarding
   to container port `80`.
