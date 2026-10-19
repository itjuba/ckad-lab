# Batch Job with completions and parallelism

Namespace: `draco`

Team Draco runs a nightly checksum task as a Kubernetes Job.

1. Write a Job manifest to `/opt/course/3/job.yaml`:
   - Job name `checksum-job`, Namespace `draco`
   - image `busybox:1.37`, container name `checksum`
   - command: `sh -c "sleep 2 && echo checksum ok"`
   - the Job must run **6** times in total, **2** at the same time
   - it must be stopped if it runs longer than **120 seconds**
   - its Pods carry the label `job-group=checksum`

2. Create the Job from that file and let it finish.

3. Write the logs of any one of the Job's Pods into `/opt/course/3/job.log`.
