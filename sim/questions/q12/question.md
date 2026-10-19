# Static PersistentVolume

Namespace: `andromeda`

Team Andromeda wants its static website content to live on a fixed directory of
the node instead of a dynamically provisioned volume.

1. Create a PersistentVolume `andromeda-pv`:
   - capacity `1Gi`, access mode `ReadWriteOnce`
   - `hostPath` `/mnt/andromeda-data`
   - no StorageClass

2. Create a PersistentVolumeClaim `andromeda-pvc` in Namespace `andromeda` that
   requests `1Gi` with access mode `ReadWriteOnce`. It must bind to
   `andromeda-pv`.

3. Create a Deployment `andromeda-store` in `andromeda` with image
   `httpd:2.4-alpine` that mounts the claim at `/usr/local/apache2/htdocs`.
