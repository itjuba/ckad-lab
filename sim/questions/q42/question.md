# Requests, limits and QoS classes

Namespace: `circinus`

Team Circinus wants to understand how resource settings affect their Pods.

1. Create a Pod `circinus-small` (image `nginx:1.29-alpine`) with requests `cpu: 100m`,
   `memory: 64Mi` and limits `cpu: 200m`, `memory: 128Mi`.
   Write its QoS class (as Kubernetes reports it) into `/opt/course/42/qos-small`.

2. Create a Pod `circinus-guaranteed` (image `nginx:1.29-alpine`) whose requests equal its
   limits: `cpu: 100m`, `memory: 64Mi`.
   Write its QoS class into `/opt/course/42/qos-guaranteed`.

3. The Deployment `circinus-api` has no resource settings. Give its container requests of
   `cpu: 50m` and `memory: 32Mi`. All replicas must be updated and available.
