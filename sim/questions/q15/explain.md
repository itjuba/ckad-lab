# Lesson 15: ConfigMaps, envFrom and immutable ConfigMaps

Curriculum: "Understand ConfigMaps"
(Application Environment, Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem ConfigMaps solve

The same image should run in dev, staging and production with different settings
(log level, URLs, timeouts). Hardcoding them in the image means one image per
environment. A ConfigMap stores settings outside the image, and the Pod reads them at
runtime as environment variables or as files.

ConfigMap = non-secret settings. For passwords and keys use a Secret (lesson 14); the
YAML for consuming both is almost identical.

------------------------------------------------------------------------------------------
## 2. Creating ConfigMaps: the three --from flags

Given a file `app.env` containing two lines, `MODE=edge` and `TIMEOUT=30s`:

```bash
k create cm demo -n demo --from-literal=MODE=edge --from-literal=TIMEOUT=30s
#   data:  MODE: edge   TIMEOUT: 30s          -> one key per literal

k create cm demo -n demo --from-env-file=app.env
#   data:  MODE: edge   TIMEOUT: 30s          -> one key PER LINE of the file

k create cm demo -n demo --from-file=app.env
#   data:  app.env: |                         -> ONE key named after the file,
#            MODE=edge                           holding the whole file as its value
#            TIMEOUT=30s
```

The difference between `--from-env-file` and `--from-file` is a classic exam detail.
Use `$do` to look at the result before creating it.

------------------------------------------------------------------------------------------
## 3. Consuming a ConfigMap as environment variables

All keys at once (variable names = key names):

```yaml
    envFrom:
    - configMapRef:
        name: demo
```

One key, with your own variable name:

```yaml
    env:
    - name: APP_MODE
      valueFrom:
        configMapKeyRef:
          name: demo
          key: MODE
```

`k set env deploy/web --from=configmap/demo` also works, but note what it writes: one
`env` entry with `configMapKeyRef` per key, not an `envFrom`. It ADDS to what's already
there, so an old reference stays unless you remove it (`k edit`).

------------------------------------------------------------------------------------------
## 4. Environment variables and rollouts

Containers read environment variables once, at startup. So:

  - editing a ConfigMap's data does NOT change running Pods
  - changing the Deployment's Pod template (for example, which ConfigMap it references)
    DOES trigger a rollout: new Pods start with the new environment

After a change:

```bash
k rollout status deploy web -n demo
k get pods -n demo                       # the new Pods have the youngest AGE
k exec -n demo <new-pod> -- sh -c 'env | grep ^MODE'
```

Quote the whole command for `sh -c '...'`. Without quotes, the `|` runs in YOUR shell,
not inside the container.

------------------------------------------------------------------------------------------
## 5. Immutable ConfigMaps

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-v2
  namespace: demo
immutable: true          # top level, next to data (not under metadata)
data:
  MODE: edge
```

Once `immutable: true` is set:
  - the data can't be changed, and it can't be set back to mutable
  - the only way to change it is delete + create
  - that's why teams version the name (`-v1`, `-v2`) and point the Deployment at the new
    one: a clean, controlled rollout, and nobody edits live config by accident

`kubectl create cm` has no flag for it: generate with `$do` into a file, add the line,
then apply.

------------------------------------------------------------------------------------------
## 6. How this applies to question 15

  Task 1  Each line of the env file must be its own key: which --from flag does that?
          Generate with $do, add `immutable: true`, apply, then check with `-o yaml`.
  Task 2  Look at how the Deployment references v1 today (`k get deploy -o yaml`, look
          under the container for `envFrom` or `env`). Change that reference to v2 so v1
          isn't mentioned anywhere.
  Task 3  Wait for the rollout, pick a NEW Pod (youngest), run the command with
          `sh -c '...'` and redirect the output into the file.
  Task 4  `k delete cm` the old one, only after the Deployment no longer uses it.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - `--from-file` instead of `--from-env-file`: one big key instead of one key per line
  - `immutable: true` placed under metadata or data
  - Adding v2 with `k set env --from` but leaving the v1 reference in place
  - Running exec against an OLD Pod that still has the old environment
  - Forgetting the quotes around `sh -c '...'`
  - Deleting v1 before switching the Deployment: new Pods can't start

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Configure a Pod to Use a ConfigMap"   create flags, env, envFrom, volumes
  Search "ConfigMaps"                           concepts, immutable ConfigMaps

See also: ckad explain 37 (ConfigMap mounted as files), ckad explain 14 (Secrets)

Now try it: ckad q 15
