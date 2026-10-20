# Lesson 38: Secrets from files, as environment variables

Curriculum: "Create & consume Secrets" (Application Environment, Configuration and
Security, 25%).

------------------------------------------------------------------------------------------
## 1. The problem

Apps need sensitive values: database passwords, API keys, tokens. They shouldn't be in
the image or in plain sight in the Deployment YAML. A Secret stores them in the cluster,
and Pods receive them as environment variables or files.

A Secret works almost exactly like a ConfigMap, with two differences:

  - values under `data:` are base64 ENCODED (encoding, not encryption: anyone who can read
    the Secret can decode it)
  - RBAC usually restricts who may read Secrets, and `describe` hides their values

------------------------------------------------------------------------------------------
## 2. Creating Secrets from files

```bash
# the WHOLE file becomes ONE key; "token=" names the key (default: the file name)
k create secret generic api-creds -n <ns> --from-file=token=./token.txt

# an env file: every KEY=value LINE becomes its own key
k create secret generic db-creds -n <ns> --from-env-file=./db.env

# typed inline
k create secret generic db-creds -n <ns> \
  --from-literal=DB_USER=app --from-literal=DB_PASS=s3cret
```

A file `db.env` with two lines:

    DB_USER=app
    DB_PASS=s3cret

gives a Secret with the keys DB_USER and DB_PASS.

Inspecting:

```bash
k describe secret db-creds -n <ns>        # key names and sizes, not the values
k get secret db-creds -n <ns> -o yaml     # values base64 encoded
echo 'czNjcmV0' | base64 -d               # decode one value: s3cret
```

------------------------------------------------------------------------------------------
## 3. Two ways to turn Secret keys into environment variables

```yaml
    spec:
      containers:
      - name: worker
        image: busybox:1.37
        command: ["sleep", "1d"]
        envFrom:                      # A) ALL keys of a Secret, names unchanged
        - secretRef:
            name: db-creds            #    -> env vars DB_USER and DB_PASS
        env:                          # B) ONE key, with a variable name you choose
        - name: API_TOKEN             #    the variable name inside the container
          valueFrom:
            secretKeyRef:
              name: api-creds         #    which Secret
              key: token              #    which key in it
```

  A) envFrom + secretRef     quick: every key becomes a variable WITH THE KEY'S NAME.
                             A key "api-key" becomes a variable literally named api-key,
                             which a shell can't use as $api-key
  B) env + secretKeyRef      precise: pick one key and give the variable the name the app
                             expects (API_KEY)

`envFrom` and `env` can be used together in the same container. For ConfigMaps it's the
same structure with `configMapRef` / `configMapKeyRef`.

------------------------------------------------------------------------------------------
## 4. kubectl set env: careful, it doesn't create envFrom

```bash
k set env deploy/worker -n <ns> --from=secret/db-creds
#   adds one env entry with secretKeyRef PER KEY (DB_USER, DB_PASS), not an envFrom block

k set env deploy/worker -n <ns> --from=secret/api-creds --keys=token
#   one env entry for one key (key names are upper-cased, dashes become underscores)
```

The resulting variables are the same, but the YAML differs. When a task explicitly says
"using envFrom", write the `envFrom` block in YAML.

------------------------------------------------------------------------------------------
## 5. Checking what the container really sees

Environment variables are read when the container STARTS. After changing a Secret or the
env setup, the Deployment rolls out new Pods (or you restart them).

```bash
k rollout status deploy/worker -n <ns>
k exec -n <ns> deploy/worker -- printenv DB_USER
k exec -n <ns> deploy/worker -- sh -c 'env | grep -e DB_ -e API | sort'  # all in the Pod
k exec -n <ns> deploy/worker -- env | grep DB_                           # grep runs locally
```

`exec deploy/<name>` picks one Pod of the Deployment for you.

------------------------------------------------------------------------------------------
## 6. How this applies to question 38

  Task 1  One file, stored under a key name that differs from the file name: use the
          `--from-file=<key>=<file>` form.
  Task 2  The env file must become one key per line: `--from-env-file`.
  Task 3  Generate the Deployment (`k create deploy ... $do -- sleep 1d`), then add an
          `envFrom` block for the DB Secret and an `env` entry with secretKeyRef for the
          API key. The variable name is given in the task.
  Task 4  Wait for the rollout, then run the given pipeline inside the Pod (wrap it in
          `sh -c '...'`) and redirect the output to the file.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - `--from-file=api-key.txt` without `<key>=`: the key is then called "api-key.txt"
  - `--from-file` for the env file: you get ONE key holding the whole file
  - Using envFrom for the API key: you'd get a variable named api-key, not API_KEY
  - Using `k set env --from` when the task requires envFrom: the grader checks envFrom
  - `secretRef` vs `secretKeyRef`: the first is for envFrom (whole Secret), the second for
    env (one key)
  - Checking an old Pod that started before your change: wait for the rollout

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Distribute Credentials Securely Using Secrets"   env and envFrom examples
  Search "Managing Secrets using kubectl"                  --from-file, --from-env-file
  Search "Secrets"                                         concept page

See also: ckad explain 14 (Secrets as env vars and as files), ckad explain 37 (ConfigMaps,
same patterns)

Now try it: ckad q 38
