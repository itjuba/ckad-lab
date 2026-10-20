# Lesson 8: Rolling updates, rollout history and rollback

Curriculum: "Understand Deployments and how to perform rolling updates"
(Application Deployment, 20%).

------------------------------------------------------------------------------------------
## 1. How a Deployment works

  Deployment  ->  ReplicaSet  ->  Pods

  - The Deployment holds the desired state: the Pod template and the number of replicas
  - Each version of the Pod template gets its own ReplicaSet (RS)
  - The RS keeps exactly N Pods of that version running

Change the template (image, env, resources...) and the Deployment creates a NEW
ReplicaSet, scales it up and scales the old one down. That's a rolling update: users keep
being served the whole time. Each template version is a numbered REVISION.

Scaling (`k scale --replicas=5`) does NOT create a revision; only template changes do.

------------------------------------------------------------------------------------------
## 2. The update strategy

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate        # default. The other type, Recreate, kills all old Pods first
    rollingUpdate:
      maxSurge: 1              # at most 1 Pod ABOVE the replica count during the update
      maxUnavailable: 0        # at most 0 Pods BELOW it (never lose capacity)
```

Both accept a number or a percentage (default 25% each). With 3 replicas, maxSurge 1 and
maxUnavailable 0, Kubernetes starts 1 new Pod, waits until it's Ready, removes 1 old Pod,
and repeats. They can't both be 0, or nothing could ever move.

```bash
k explain deploy.spec.strategy.rollingUpdate
```

------------------------------------------------------------------------------------------
## 3. Triggering an update

```bash
k set image deploy/web web=nginx:1.29-alpine -n perseus   # <container-name>=<image>
k edit deploy web -n perseus                              # any template change
k rollout restart deploy/web -n perseus                   # new Pods, same spec
```

`set image` needs the CONTAINER name, which often differs from the Deployment name:

```bash
k describe deploy web -n perseus | grep -A1 Containers
```

------------------------------------------------------------------------------------------
## 4. Following and undoing rollouts

```bash
k rollout status deploy/web -n perseus          # waits until done (or shows it's stuck)
k rollout history deploy/web -n perseus         # list of revisions + CHANGE-CAUSE
k rollout history deploy/web -n perseus --revision=3   # details: image etc.
k rollout undo deploy/web -n perseus            # back to the previous revision
k rollout undo deploy/web -n perseus --to-revision=2   # back to a specific one
k rollout pause deploy/web -n perseus           # batch several changes, then
k rollout resume deploy/web -n perseus          # roll them out at once
k get rs -n perseus                             # one RS per revision, with its Pod count
```

A broken update (for example a non-existent image) gets stuck: the new Pod sits in
ImagePullBackOff while the old Pods keep serving. That's the rolling update protecting
you. `k get pods` and `k describe pod <new-pod>` show why it's stuck.

Rolling back doesn't restore the old NUMBER: undoing to revision 2 creates a new revision
(for example 4) with revision 2's template, and 2 disappears from the list.

------------------------------------------------------------------------------------------
## 5. Change cause: labelling revisions

The CHANGE-CAUSE column comes from the annotation `kubernetes.io/change-cause` on the
Deployment. Set it when you make a change; it's stored with the newest revision:

```bash
k annotate deploy/web -n perseus kubernetes.io/change-cause="upgrade to 1.29" --overwrite
```

(The old `--record` flag is deprecated; the annotation is what it used to set.)

------------------------------------------------------------------------------------------
## 6. How this applies to question 8

  Task 1  Read the rollout history and check each revision's image (or change cause). The
          newest revision is the broken one; find the newest one before it that worked.
  Task 2  Undo to exactly that revision.
  Task 3  Edit the Deployment's `strategy` so it matches "1 extra Pod, 0 unavailable".
  Task 4  Change the image (find the container name first), set the change cause on the
          Deployment, and wait for the rollout to finish with all 3 Pods updated.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Using the Deployment name as the container name in `set image`
  - Writing the revision number of the broken revision, or expecting the rollback to
    keep the old number
  - Typing `maxSurge`/`maxUnavailable` at the wrong level (they go under
    `strategy.rollingUpdate`, not directly under `spec`)
  - Annotating the Pod template instead of the Deployment, or forgetting --overwrite when
    the annotation already exists

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Deployments"   sections "Updating a Deployment", "Rolling Back a Deployment",
                         "Strategy" (maxSurge, maxUnavailable)

See also: ckad explain 31 (Deployment basics), ckad explain 26 and 22 (blue/green, canary)

Now try it: ckad q 8
