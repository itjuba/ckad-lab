# Lesson 3: Jobs, run-to-completion workloads

Curriculum: "Choose and use the right workload resource (Deployment, DaemonSet, CronJob,
etc.)" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem Jobs solve

A web server should run forever. A database migration, a report, a backup should run,
finish, and stop. If you used a Deployment for that, Kubernetes would restart it forever.

  Deployment   keep N Pods running all the time        (web servers, APIs)
  Job          run Pods until they succeed, then stop  (batch tasks, one-off scripts)
  CronJob      create a Job on a schedule               (nightly backups, see lesson 19)

------------------------------------------------------------------------------------------
## 2. The Job manifest

```yaml
apiVersion: batch/v1          # Jobs live in the "batch" API group
kind: Job
metadata:
  name: report
  namespace: draco            # labels HERE label the Job object itself
spec:
  completions: 4              # how many successful Pod runs in total (default 1)
  parallelism: 2              # how many Pods at the same time (default 1)
  backoffLimit: 3             # retries before the Job is marked Failed (default 6)
  activeDeadlineSeconds: 60   # the whole Job is stopped after 60s, done or not
  template:                   # a Pod template: everything below is a Pod spec
    metadata:
      labels:
        job-group: reports    # labels HERE end up on every Pod the Job creates
    spec:
      restartPolicy: Never    # Never or OnFailure. Always is NOT allowed in a Job
      containers:
      - name: report
        image: busybox:1.37
        command: ["sh", "-c", "echo generating; sleep 2"]
```

With completions 4 and parallelism 2, the Job runs 2 Pods, then 2 more: 4 in total.

Other useful fields: `ttlSecondsAfterFinished` (delete the finished Job after N seconds;
careful, then you can't read its logs anymore).

------------------------------------------------------------------------------------------
## 3. Template = the Pods, not the Job

`spec.template` is a Pod description. Deployments, Jobs, CronJobs and DaemonSets all use
this pattern: the controller stamps out Pods from the template. So:

  metadata.labels                     -> on the Job object
  spec.template.metadata.labels       -> on the Pods          <- usually what tasks want
  spec.template.spec.containers       -> the containers

A Job's template can't be changed after creation. To fix it: edit your YAML file,
`k delete job <name>`, then `k apply -f` again.

------------------------------------------------------------------------------------------
## 4. The commands

```bash
# generate a Job; the command goes after --
k create job report -n draco --image=busybox:1.37 $do -- sh -c "echo hi" > job.yaml
vim job.yaml               # add completions, parallelism, labels, rename the container...
k apply -f job.yaml

k get job -n draco         # COMPLETIONS 2/4, DURATION
k get pods -n draco        # Pods are named <job>-<random>, STATUS Completed when done
k get job,pod -n draco -w  # watch until done (Ctrl+C to stop watching)

k logs job/report -n draco           # logs of one of the Job's Pods
k describe job report -n draco       # Events: created Pods, failures, deadline exceeded
k explain job.spec                   # all Job fields
```

`k create job` names the container after the Job, and it can't set completions,
parallelism or labels: edit those in the YAML.

------------------------------------------------------------------------------------------
## 5. How this applies to question 3

  Task 1  Generate the Job YAML straight into the required file, then edit: total runs,
          runs at the same time, the deadline, the container name, and the Pod label.
          Ask yourself for every field: is it Job-level (spec) or Pod-level
          (spec.template)?
  Task 2  Apply the file and watch until all runs complete.
  Task 3  Logs of any one Pod of the Job, redirected into the file.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Pod label in the Job's `metadata` instead of `spec.template.metadata` (or a typo:
    the grader checks the exact key)
  - Leaving the container named after the Job
  - `restartPolicy: Always`: rejected for Jobs
  - Changing the YAML file but not recreating the Job (the running Job keeps its old spec)
  - Mixing up `completions` (total) and `parallelism` (at once)

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Jobs"        completions, parallelism, backoffLimit, activeDeadlineSeconds
  `k explain job.spec.backoffLimit`   field docs in the terminal

See also: ckad explain 33 (a failing Job), ckad explain 19 (CronJobs)

Now try it: ckad q 3
