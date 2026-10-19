# Solution 19

```bash
k create cronjob rigel-report -n rigel --image=busybox:1.37 --schedule="*/15 * * * *" $do \
  -- sh -c 'date; echo report generated' > 19.yaml
vim 19.yaml
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rigel-report
  namespace: rigel
spec:
  schedule: "*/15 * * * *"
  concurrencyPolicy: Forbid          # added: no overlapping runs
  successfulJobsHistoryLimit: 2      # added
  failedJobsHistoryLimit: 1          # added
  startingDeadlineSeconds: 60        # added: skip runs that start too late
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure   # generated default, and what the task asks for
          containers:
          - name: rigel-report
            image: busybox:1.37
            command: ["sh", "-c", "date; echo report generated"]
```

```bash
k apply -f 19.yaml

# 2. Run it now
k create job rigel-report-manual -n rigel --from=cronjob/rigel-report
k get job,pod -n rigel

# 3.
k logs -n rigel job/rigel-report-manual > /opt/course/19/manual.log
```

Remember:
- The scheduling fields (`concurrencyPolicy`, history limits, `startingDeadlineSeconds`) go in the CronJob's `spec`. The Pod settings go under `jobTemplate.spec.template.spec`.
- `restartPolicy: OnFailure` restarts the container in the same Pod. `Never` creates a new Pod for every retry.
- Use `--from=cronjob/<name>` to test a CronJob without changing its schedule.
