# Rollout history and rollback

Namespace: `perseus`

The Deployment `perseus-web` was updated several times today. The latest
update broke the rollout.

1. Find the most recent revision of `perseus-web` that worked and write its
   revision number into `/opt/course/8/good-revision`.

2. Roll `perseus-web` back to that revision.

3. Change the Deployment's update strategy so that during a rolling update at
   most **1** extra Pod is created and **no** Pod is unavailable.

4. Update the Deployment to image `nginx:1.29-alpine`. The rollout history must
   show the change cause `upgrade to 1.29` for the new revision. All 3 replicas
   must be updated and available.
