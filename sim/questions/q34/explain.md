# Lesson 34: CronJobs: schedule, time zone, suspend and history

Curriculum: "Choose and use the right workload resource (Deployment, DaemonSet, CronJob,
etc.)" (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. The problem

Some tasks must run on a timetable: a backup every night, a cleanup every hour, a report
every Monday. A CronJob is a Job factory: on every scheduled time it creates a new Job,
and that Job creates the Pod that does the work.

    CronJob  --(every scheduled time)-->  Job  -->  Pod

------------------------------------------------------------------------------------------
## 2. The schedule: cron syntax

Five fields, separated by spaces:

    +--------- minute        (0-59)
    | +------- hour          (0-23)
    | | +----- day of month  (1-31)
    | | | +--- month         (1-12)
    | | | | +- day of week   (0-6, 0 = Sunday)
    | | | | |
    * * * * *

  * * * * *       every minute
  */15 * * * *    every 15 minutes
  0 2 * * *       every day at 02:00
  0 */6 * * *     minute 0 of every 6th hour: 00:00, 06:00, 12:00, 18:00
  0 9 * * 1       Mondays at 09:00

`*` means "every", `*/n` means "every n-th", and a list like `0,30` means "at 0 and 30".

------------------------------------------------------------------------------------------
## 3. The CronJob fields you'll meet

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-backup
spec:
  schedule: "0 2 * * *"           # when (quote it: * has a meaning in YAML)
  timeZone: Europe/Paris          # which clock the schedule uses (default: the cluster's)
  suspend: false                  # true = pause: no NEW Jobs are created
  concurrencyPolicy: Forbid       # Allow (default) / Forbid / Replace overlapping runs
  successfulJobsHistoryLimit: 3   # how many finished Jobs to keep (default 3)
  failedJobsHistoryLimit: 1       # how many failed Jobs to keep (default 1)
  jobTemplate:                    # a full Job spec: what each run does
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox:1.37
            command: ["sh", "-c", "date; echo backup done"]
```

Note the nesting: CronJob spec -> jobTemplate.spec (the Job) -> template.spec (the Pod).
All the scheduling fields sit directly under the CronJob's `spec`, next to `schedule`.

`suspend: true` only stops new runs. A Job that's already running finishes normally.

------------------------------------------------------------------------------------------
## 4. Commands

```bash
# create one (restartPolicy OnFailure is set for you)
k create cronjob nightly-backup -n <ns> --image=busybox:1.37 --schedule="0 2 * * *" $do \
  -- sh -c 'date; echo backup done' > cj.yaml

k get cronjob -n <ns>          # SCHEDULE, TIMEZONE, SUSPEND, ACTIVE, LAST SCHEDULE columns

# change an existing one
k edit cronjob nightly-backup -n <ns>                              # opens it in vim
k patch cronjob nightly-backup -n <ns> -p '{"spec":{"suspend":false}}'   # one field

# run it NOW without waiting for the schedule
k create job manual-run -n <ns> --from=cronjob/nightly-backup
k get job -n <ns>                                   # wait for COMPLETIONS 1/1
k logs job/manual-run -n <ns>

# look up a field
k explain cronjob.spec.timeZone
```

`--from=cronjob/<name>` copies the CronJob's jobTemplate into a new Job, and Kubernetes
records that it was triggered manually. It's the standard way to test a CronJob.

------------------------------------------------------------------------------------------
## 5. How this applies to question 34

  Start   `k get cronjob -n scutum` shows the current SCHEDULE, TIMEZONE and SUSPEND.
  1-4     All four changes are fields directly under the CronJob's `spec`: the schedule,
          the time zone, suspend, and the two history limits. One `k edit` covers them.
          Afterwards, `k get cronjob` should show the new schedule, the time zone and
          SUSPEND False.
  5       Create the Job from the CronJob with --from, wait for it to complete, then save
          its logs.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Putting the time zone into the schedule string ("TZ=..." or "CRON_TZ=..."). Use the
    separate `timeZone` field
  - Putting `suspend` or the history limits inside jobTemplate: they belong to the CronJob
  - Unquoted schedules in YAML: `schedule: */6 ...` breaks, `schedule: "0 */6 * * *"` works
  - Mixing up the field order: the first field is the MINUTE, not the hour
  - Creating the manual Job with `k create job --image=...` instead of `--from`: it then
    isn't linked to the CronJob
  - Reading logs before the Job finished

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "CronJob"              concept page: schedule syntax, time zones, history limits
  Search "Running Automated Tasks with a CronJob"    task page with a full example
  Search "kubectl create job"   for --from=cronjob/<name>

See also: ckad explain 19 (CronJob with concurrency and a manual run), ckad explain 33
(Jobs that fail)

Now try it: ckad q 34
