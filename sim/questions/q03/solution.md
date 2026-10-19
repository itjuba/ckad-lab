# Solution 3

```bash
k create job checksum-job -n draco --image=busybox:1.37 $do \
  -- sh -c "sleep 2 && echo checksum ok" > /opt/course/3/job.yaml
vim /opt/course/3/job.yaml
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: checksum-job
  namespace: draco
spec:
  completions: 6                 # total successful runs
  parallelism: 2                 # at the same time
  activeDeadlineSeconds: 120     # whole Job is stopped after 120s
  template:
    metadata:
      labels:
        job-group: checksum      # Pod label, under template.metadata
    spec:
      restartPolicy: Never
      containers:
      - name: checksum           # was: checksum-job
        image: busybox:1.37
        command: ["sh", "-c", "sleep 2 && echo checksum ok"]
```

```bash
k apply -f /opt/course/3/job.yaml
k get job,pod -n draco -w          # wait for COMPLETIONS 6/6
k logs -n draco job/checksum-job > /opt/course/3/job.log
```

The Pod label goes under `spec.template.metadata.labels`. Labels in the Job's
own `metadata` don't reach the Pods.
