# Debug and replace a failing Job

Namespace: `sagitta`

The import Job `sagitta-import` in Namespace `sagitta` has failed.

1. Write the reason Kubernetes gives for the Job's failure (one word, the reason of the
   Job's `Failed` condition) into `/opt/course/33/job-reason`.

2. Write the error line from the logs of one of the Job's Pods into
   `/opt/course/33/error.log`.

3. Replace the Job with a new Job of the **same name** `sagitta-import`:
   - image `busybox:1.37`
   - command `sh -c 'mkdir -p /data && echo id,name > /data/input.csv && cat /data/input.csv'`
   - `backoffLimit: 4`, `restartPolicy: Never`

   Let it complete.

4. Write the logs of the new Job into `/opt/course/33/job.log`.
