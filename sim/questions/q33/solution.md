# Solution 33

Investigate first:

```bash
k get job,pod -n sagitta                    # COMPLETIONS 0/1, Pods in Error
k describe job sagitta-import -n sagitta    # Events: Warning  BackoffLimitExceeded
echo BackoffLimitExceeded > /opt/course/33/job-reason

k logs -n sagitta <one-of-the-pods>         # importing / cat: can't open '/data/input.csv': ...
k logs -n sagitta <one-of-the-pods> | grep -i "can't open" > /opt/course/33/error.log
```

A Job's Pod template can't be edited, so replace the Job. Generate a new one with the
right command:

```bash
k delete job sagitta-import -n sagitta      # also deletes its Pods
k create job sagitta-import -n sagitta --image=busybox:1.37 $do \
  -- sh -c 'mkdir -p /data && echo id,name > /data/input.csv && cat /data/input.csv' > 33.yaml
vim 33.yaml
```

```yaml
spec:
  backoffLimit: 4                 # added (default is 6)
  template:
    spec:
      restartPolicy: Never        # already set by kubectl create job
      containers:
      - name: sagitta-import
        image: busybox:1.37
        command: [...]            # from the -- part
```

```bash
k apply -f 33.yaml
k get job sagitta-import -n sagitta -w      # COMPLETIONS 1/1
k logs -n sagitta job/sagitta-import > /opt/course/33/job.log
```

Remember:
- `backoffLimit` is how many failed Pods a Job allows before it gives up with
  `BackoffLimitExceeded`.
- With `restartPolicy: Never`, every retry is a new Pod, so you can read each failed
  attempt's logs. With `OnFailure`, the same Pod restarts and you need `k logs --previous`.
- `k apply` on a changed Job template fails with "field is immutable". Delete, then create.
