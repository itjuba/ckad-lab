# Lesson 33: Debugging and replacing a failed Job

Curriculum: "Choose and use the right workload resource (Deployment, DaemonSet, CronJob,
etc.)" (Application Design and Build, 20%) and "Debugging in Kubernetes" (Application
Observability and Maintenance, 15%).

------------------------------------------------------------------------------------------
## 1. The problem

A Job runs a task to completion: a nightly import, a database migration, a report. Unlike
a Deployment, it isn't supposed to run forever. It's done when the task succeeded.

But tasks fail: a missing file, a wrong command, a database that's down. You need to know:

  - How often does Kubernetes retry before giving up?
  - Where do you find WHY it gave up?
  - How do you fix a Job, when most of a Job can't be edited?

------------------------------------------------------------------------------------------
## 2. Retries: backoffLimit

When a Job's Pod fails (its container exits with a non-zero code), the Job retries. Each
retry waits longer (about 10s, 20s, 40s, ... up to 6 minutes). After too many failures
the Job stops and is marked Failed.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: report
spec:
  backoffLimit: 3               # give up after 3 retries (default: 6)
  activeDeadlineSeconds: 300    # optional: give up after 5 minutes, retries or not
  template:                     # the Pod template: what each attempt runs
    spec:
      restartPolicy: Never      # Never or OnFailure. Always isn't allowed in a Job
      containers:
      - name: report
        image: busybox:1.37
        command: ["sh", "-c", "echo building report; exit 1"]   # exit 1 = failure
```

The reason recorded when a Job gives up:

  BackoffLimitExceeded   too many failed attempts (backoffLimit reached)
  DeadlineExceeded       activeDeadlineSeconds ran out

------------------------------------------------------------------------------------------
## 3. restartPolicy decides where the evidence is

  Never       every retry is a NEW Pod. The failed Pods stay (STATUS Error), so you can
              read the logs of each failed attempt with `k logs <pod>`.
  OnFailure   the SAME Pod restarts its container. Only the last crash is kept:
              `k logs <pod> --previous` shows it.

`kubectl create job` sets restartPolicy: Never for you.

------------------------------------------------------------------------------------------
## 4. Finding out why a Job failed

```bash
k get job,pod -n <ns>              # Job STATUS Failed, COMPLETIONS 0/1, Pods in Error
k describe job <name> -n <ns>      # Backoff Limit, Pods Statuses, and Events at the bottom
k logs <pod-name> -n <ns>          # what the container printed before it failed
k logs job/<name> -n <ns>          # same, kubectl picks one of the Job's Pods
```

In `describe job`, the Events section shows a line like:

    Warning  BackoffLimitExceeded  ...  Job has reached the specified backoff limit

The middle word (BackoffLimitExceeded) is the REASON. The text after it is the MESSAGE.

Events expire after about an hour. If `describe` says `Events: <none>`, the reason is
still stored in the Job's status conditions:

```bash
k get job <name> -n <ns> -o yaml | grep reason       # reason: BackoffLimitExceeded
```

------------------------------------------------------------------------------------------
## 5. Fixing a Job: delete and recreate

A Job's Pod template is immutable. Changing the command or image with `k edit` or
`k apply` fails with "field is immutable". The way out:

```bash
k get job <name> -n <ns> -o yaml > old.yaml    # optional: keep a copy
k delete job <name> -n <ns>                    # also deletes its Pods and their logs!

k create job <name> -n <ns> --image=busybox:1.37 $do \
  -- sh -c 'mkdir -p /out && date > /out/now.txt && cat /out/now.txt' > job.yaml
vim job.yaml                                   # add backoffLimit (create job can't)
k apply -f job.yaml
k get job <name> -n <ns> -w                    # wait for COMPLETIONS 1/1, Ctrl+C to stop
```

`k replace --force -f job.yaml` deletes and recreates in one step.

Quoting matters here. Everything inside the single quotes, including `&&` and `>`, is
passed to the container's shell. The final `> job.yaml` is OUTSIDE the quotes, so your own
shell uses it to save kubectl's YAML output.

------------------------------------------------------------------------------------------
## 6. How this applies to question 33

  Task 1  Look at the failed Job with `describe`. The answer is the one-word reason, not
          the whole line. If the Events have expired, use the `-o yaml | grep reason`
          fallback from section 4.
  Task 2  Read the logs of one failed Pod. One line explains the failure. Save just that
          line (grep for a word in it).
  Task 3  Do tasks 1 and 2 FIRST: deleting the Job deletes its Pods and their logs. Then
          delete the Job and generate a new one with the same name and the new command.
          Add backoffLimit in vim. Check restartPolicy.
  Task 4  Wait until the new Job shows COMPLETIONS 1/1, then save its logs.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Deleting the old Job before saving its logs: the evidence is gone with its Pods
  - Writing the whole event line, or the message, when the task asks for the reason
  - Trying to `k edit` the Job's command: the template is immutable, recreate the Job
  - Putting backoffLimit under `template.spec`: it belongs directly under the Job's `spec`
  - Forgetting the single quotes around the `sh -c` script, so your shell runs the `>`
  - Saving the logs before the new Job finished: wait for COMPLETIONS 1/1

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Jobs"                    concept page, sections "Pod backoff failure policy"
                                   and "Job termination and cleanup"
  Search "kubectl create job"      the command reference
  `k explain job.spec.backoffLimit`    field documentation in the terminal

See also: ckad explain 3 (Job basics), ckad explain 34 (CronJobs)

Now try it: ckad q 33
