# Dynamic provisioning and WaitForFirstConsumer

Namespace: `centaurus`

Team Centaurus needs a small cache volume, created on demand by the cluster's
`local-path` StorageClass.

1. Create a PersistentVolumeClaim `centaurus-cache` in Namespace `centaurus`:
   `500Mi`, access mode `ReadWriteOnce`, StorageClass `local-path`.

2. Before anything uses the claim, write its status into
   `/opt/course/13/status-before`. Write the event message that explains this
   status into `/opt/course/13/pending-reason`.

3. Create a Pod `cache-writer` in `centaurus`, image `busybox:1.37`, that mounts
   the claim at `/cache` and appends the output of `date` to `/cache/date.log`
   every 10 seconds.

4. Write the name of the PersistentVolume that was provisioned for the claim
   into `/opt/course/13/pv-name`.
