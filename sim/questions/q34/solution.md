# Solution 34

Look first, then edit the CronJob in place:

```bash
k get cronjob -n scutum                      # SUSPEND True, SCHEDULE * * * * *
k edit cronjob scutum-backup -n scutum
```

```yaml
spec:
  schedule: "0 */6 * * *"          # was: "* * * * *"
  timeZone: Europe/Paris           # added, next to schedule
  suspend: false                   # was: true
  successfulJobsHistoryLimit: 1    # was: 3
  failedJobsHistoryLimit: 1        # was: 3
  jobTemplate:
    ...
```

```bash
k get cronjob -n scutum                      # SUSPEND False, new schedule

# run it once now
k create job scutum-backup-now -n scutum --from=cronjob/scutum-backup
k get job -n scutum                          # wait for COMPLETIONS 1/1
k logs -n scutum job/scutum-backup-now > /opt/course/34/backup.log
```

A single field is quicker with `patch`:

```bash
k patch cronjob scutum-backup -n scutum -p '{"spec":{"suspend":false}}'
```

Remember:
- `timeZone` is its own field in the CronJob spec. Don't put `TZ=` into the schedule string.
  `k explain cronjob.spec.timeZone` shows it.
- Cron fields are minute, hour, day of month, month, day of week. `0 */6 * * *` means minute 0
  of every 6th hour.
- `--from=cronjob/<name>` copies the CronJob's job template. It's the quickest way to test a
  CronJob.
- Suspending only stops new Jobs from being created. Jobs that are already running keep going.
