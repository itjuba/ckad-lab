# Pods stuck in Pending

Namespace: `volans`

Nothing that team Volans deployed today has started. All of their Pods stay `Pending`.

1. Write the scheduling event message of the Pods of Deployment `volans-api` into
   `/opt/course/40/api-reason`.

2. Fix `volans-api` **without changing the Deployment**: the Pods are meant to run on
   node `k3d-ckad-agent-0`, so give that node what the Pods are asking for. Both replicas
   must then run on `k3d-ckad-agent-0`.

3. Write the reason the Pod `volans-batch` can't be scheduled into
   `/opt/course/40/batch-reason`.

4. Recreate `volans-batch` with the same name and image, but requesting `100m` CPU, so it
   runs.
