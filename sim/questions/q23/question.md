# Custom resources and removed API versions

Namespace: `pollux`

Nimbus installed a backup operator. It added a CustomResourceDefinition for
`Backup` resources in the API group `nimbus.io`.

1. Create a Backup named `nightly` in Namespace `pollux` with:
   - schedule `0 2 * * *`
   - retention of `7` days
   - target `pollux-web`

   Use the CRD to find the exact field names.

2. Write the short name of the Backup resource type into `/opt/course/23/short-name`.

3. Team Pollux keeps old manifests for Deployment `pollux-web` in
   `/opt/course/23/legacy/` (`hpa.yaml` and `pdb.yaml`). Neither applies on
   this cluster anymore. Update both files **in place** to API versions this
   cluster serves, keeping the same settings, then apply them.
