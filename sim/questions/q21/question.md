# ResourceQuota blocks a Deployment

Namespace: `deneb`

Team Deneb deployed `deneb-app` (3 replicas), but none of its Pods ever
appear. The Namespace has a ResourceQuota.

1. Find out why no Pods are created. Write the error message from the events
   into `/opt/course/21/reason`.

2. Fix Deployment `deneb-app` so all 3 replicas run. Each container gets:
   - requests: cpu `100m`, memory `64Mi`
   - limits: cpu `200m`, memory `128Mi`

3. So this doesn't happen again, create a LimitRange named `deneb-defaults` in
   `deneb` that gives every container these defaults when it sets none:
   - default requests: cpu `50m`, memory `32Mi`
   - default limits: cpu `100m`, memory `64Mi`

4. Create a Pod `deneb-probe` (image `nginx:1.29-alpine`) **without** any
   resources in its spec. Confirm it's Running and got the defaults.
