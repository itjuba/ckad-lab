# Lesson 19: CronJobs

Curriculum: "Choose and use the right workload resource (Deployment, DaemonSet, CronJob,
etc.)" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. Job vs CronJob

  Deployment  keeps Pods running forever (a web server)
  Job         runs Pods until the task SUCCEEDS, then stops (a migration, a report)
  CronJob     creates a new Job on a schedule (a report every 15 minutes, a nightly backup)

  CronJob --(every schedule tick)--> Job --> Pod(s) --> exit 0 = done

A CronJob is a Job factory. The Jobs and Pods it creates are normal Jobs and Pods you can
inspect with `k get job,pod` and `k logs`.

------------------------------------------------------------------------------------------
## 2. Cron schedule syntax

Five fields: minute, hour, day of month, month, day of week.

  "*/15 * * * *"     every 15 minutes            (*/n = every n)
  "0 * * * *"        at minute 0 of every hour
  "0 */6 * * *"      every 6 hours, on the hour
  "0 2 * * *"        every day at 02:00
  "30 8 * * 1-5"     08:30 Monday to Friday
  "0 0 1 * *"        midnight on the 1st of every month

Quote the schedule in YAML and on the command line (it contains `*`).

------------------------------------------------------------------------------------------
## 3. The YAML, level by level

The nesting is the main thing to get right:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: demo-report
  namespace: demo
spec:                                  # --- CronJob level: WHEN and HOW OFTEN ---
  schedule: "*/15 * * * *"
  concurrencyPolicy: Forbid            # Allow (default) | Forbid | Replace
  successfulJobsHistoryLimit: 3        # keep the last 3 successful Jobs (default 3)
  failedJobsHistoryLimit: 1            # keep the last failed Job (default 1)
  startingDeadlineSeconds: 120         # skip a run that can't start within 120s
  suspend: false                       # true = pause the schedule
  jobTemplate:
    spec:                              # --- Job level: retries, completions ---
      backoffLimit: 2
      template:
        spec:                          # --- Pod level: containers, restartPolicy ---
          restartPolicy: OnFailure
          containers:
          - name: report
            image: busybox:1.37
            command: ["sh", "-c", "date; echo done"]
```

What the CronJob-level fields mean:
  concurrencyPolicy      what happens if the previous run is still going at the next tick
                         Allow = run both, Forbid = skip the new one, Replace = stop the
                         old one and start the new one
  *HistoryLimit          how many finished Jobs stay visible (older ones get deleted)
  startingDeadlineSeconds  if the controller can't start a run within this many seconds
                         of its scheduled time (it was down, or Forbid blocked it), skip it

restartPolicy for Job Pods must be OnFailure or Never (Always isn't allowed):
  OnFailure   a failed container is restarted inside the SAME Pod
  Never       the Pod stays failed; the Job creates a NEW Pod for the retry

------------------------------------------------------------------------------------------
## 4. The commands

```bash
# generate: everything after -- becomes the container command
k create cronjob demo-report -n demo --image=busybox:1.37 --schedule="*/15 * * * *" $do \
  -- sh -c 'date; echo done' > cj.yaml
vim cj.yaml                            # add the CronJob-level fields under spec:
k apply -f cj.yaml
k get cronjob -n demo                  # SCHEDULE, SUSPEND, ACTIVE, LAST SCHEDULE

# run it NOW, without waiting for the schedule
k create job demo-report-now -n demo --from=cronjob/demo-report
k get job,pod -n demo
k logs -n demo job/demo-report-now

k explain cronjob.spec                 # all fields with descriptions
```

The generated YAML already has `restartPolicy: OnFailure`.

------------------------------------------------------------------------------------------
## 5. How this applies to question 19

  Task 1  Generate with `k create cronjob ... $do -- sh -c '...'`. Then translate each
          plain-English requirement into a CronJob-level field (section 3): "must not start
          while the previous is active", "keep 2 successful / 1 failed", "can't start
          within 60 seconds", and check which restartPolicy "restarted in the same Pod"
          means.
  Task 2  `k create job <name> --from=cronjob/<cronjob>`.
  Task 3  Wait until the Job completes, then `k logs job/<name>` into the file.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Putting concurrencyPolicy or the history limits under jobTemplate or the Pod spec
  - Unquoted schedule: the shell expands `*` into file names
  - `restartPolicy: Never` when the task says "restart in the same Pod"
  - Waiting 15 minutes for the schedule instead of using `--from=cronjob/...`
  - `k logs <cronjob>`: logs belong to the Job/Pod, not the CronJob

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "CronJob"                                    fields, schedule syntax, policies
  Search "Running Automated Tasks with a CronJob"     a complete example

See also: ckad explain 3 (Jobs), ckad explain 34 (suspended CronJob, timeZone),
          ckad explain 33 (a failing Job)

Now try it: ckad q 19
