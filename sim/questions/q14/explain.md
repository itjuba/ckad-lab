# Lesson 14: Secrets as environment variables and as files

Curriculum: "Create & consume Secrets"
(Application Environment, Configuration and Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem Secrets solve

Passwords, API keys and certificates shouldn't be baked into an image or written into a
Deployment's YAML. A Secret stores them as a separate object, and Pods read them at
runtime, either as environment variables or as files.

Secret vs ConfigMap: same idea, same ways to consume them. Use a Secret for sensitive
values (access can be restricted with RBAC) and a ConfigMap for normal settings.

Important: Secret values are base64 ENCODED, not encrypted. Anyone who can read the
Secret can decode it with `base64 -d`.

------------------------------------------------------------------------------------------
## 2. Creating Secrets

```bash
# key=value pairs
k create secret generic db-demo -n demo \
  --from-literal=user=alice --from-literal='pass=Pa$$!'

# a file: the key is the file name (or name it: --from-file=mykey=./file.txt)
k create secret generic cert-demo -n demo --from-file=ca.crt=./ca.crt

# an env file: one key per line (KEY=value)
k create secret generic env-demo -n demo --from-env-file=./db.env
```

Single quotes around values with `!`, `$` or spaces stop the shell from changing them.

What it looks like:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-demo
  namespace: demo
type: Opaque                 # "generic" = Opaque. Others: kubernetes.io/tls, ...
data:
  user: YWxpY2U=             # base64 of "alice"
```

Applying a manifest someone gave you: read it first. If its metadata says
`namespace: default`, then `k apply -f file -n demo` fails with a namespace mismatch.
Change the namespace in the file, then apply.

------------------------------------------------------------------------------------------
## 3. Consuming a Secret as environment variables

One variable per key, with your own variable name:

```yaml
    env:
    - name: DB_USER                # the variable name inside the container
      valueFrom:
        secretKeyRef:
          name: db-demo            # which Secret
          key: user                # which key in it
```

All keys at once (variable names = key names):

```yaml
    envFrom:
    - secretRef:
        name: env-demo
```

------------------------------------------------------------------------------------------
## 4. Consuming a Secret as files (a volume)

Every key becomes a file in the mount directory:

```yaml
spec:
  containers:
  - name: app
    image: busybox:1.37
    volumeMounts:
    - name: certs
      mountPath: /etc/certs
      readOnly: true               # the container can't change the files
  volumes:
  - name: certs
    secret:
      secretName: cert-demo
```

To expose only some keys, or rename them, use `items`:

```yaml
  volumes:
  - name: certs
    secret:
      secretName: cert-demo
      items:                       # once present, ONLY listed keys appear
      - key: ca.crt                # key in the Secret
        path: root.pem             # file name inside the mount
        mode: 0400                 # this file's permissions
      defaultMode: 0440            # (optional) mode for files without their own `mode`
```

File modes are octal: 0400 = owner can read, nothing else. Write the leading 0 so YAML
reads it as octal; plain 400 is a decimal number and gives a different mode.

Differences between the two ways:
  env vars   read once when the container starts; a changed Secret needs a new Pod
  files      updated automatically (after a short delay) when the Secret changes

------------------------------------------------------------------------------------------
## 5. Checking your work inside the Pod

```bash
k exec -n demo app -- printenv DB_USER
k exec -n demo app -- ls -l /etc/certs
k exec -n demo app -- cat /etc/certs/root.pem
k exec -n demo app -- stat -L -c %a /etc/certs/root.pem     # prints e.g. 400
```

Files in a Secret volume are symlinks, so plain `ls -l` shows the link. `stat -L`
follows the link and shows the real file's mode.

Generating the Pod: `k run app -n demo --image=busybox:1.37 $do --command -- sleep 1d`
gives you a skeleton; add `env`, `volumeMounts` and `volumes` in vim.

------------------------------------------------------------------------------------------
## 6. How this applies to question 14

  Task 1  One `k create secret generic` with two `--from-literal`. Watch the `!` in the
          password: quote it.
  Task 2  Open the given manifest before applying it. Which namespace does it name?
  Task 3  Two `env` entries with `secretKeyRef` (the variable names differ from the key
          names). Then one Secret volume with `items` so only one key appears, under a new
          file name, with mode 0400, mounted read-only at the given path. Verify with
          printenv, ls and `stat -L`.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Unquoted `!` in a literal: the shell changes or rejects it
  - Applying a manifest whose namespace differs from where it should go
  - Forgetting `items`: every key shows up as a file
  - `mode: 400` without the leading 0 (decimal, wrong permissions)
  - Forgetting `readOnly: true` on the volumeMount when the task asks for read-only
  - Writing base64 values into `stringData` (stringData takes plain text)

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Distribute Credentials Securely Using Secrets"   env + volume examples
  Search "Secrets"                                         concepts, types, items
  `k explain pod.spec.volumes.secret.items`                fields without the docs

See also: ckad explain 38 (Secrets from files into env), ckad explain 15 (ConfigMaps)

Now try it: ckad q 14
