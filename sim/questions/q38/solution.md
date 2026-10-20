# Solution 38

The two ways of creating a Secret from files:

```bash
# --from-file=<key>=<file>: the whole file becomes ONE key
k create secret generic norma-api -n norma --from-file=api-key=/opt/course/38/api-key.txt

# --from-env-file: every KEY=value line becomes its own key
k create secret generic norma-db -n norma --from-env-file=/opt/course/38/db.env
k describe secret norma-db -n norma            # DB_HOST, DB_PORT
```

Generate the Deployment and add the env parts (docs search: "distribute credentials secure"):

```bash
k create deploy norma-worker -n norma --image=busybox:1.37 $do -- sleep 1d > 38.yaml
vim 38.yaml
```

```yaml
    spec:
      containers:
      - name: busybox
        image: busybox:1.37
        command: ["sleep", "1d"]
        envFrom:                    # added: every key of the Secret
        - secretRef:
            name: norma-db
        env:                        # added: one key, with your own variable name
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: norma-api
              key: api-key
```

```bash
k apply -f 38.yaml
k rollout status deploy norma-worker -n norma
k exec -n norma deploy/norma-worker -- sh -c 'env | grep -e DB_ -e API_KEY | sort' > /opt/course/38/env.txt
cat /opt/course/38/env.txt
```

`k exec ... -- env | grep -e DB_ -e API_KEY | sort > file` works too. Then `grep` and `sort`
run in your terminal instead of in the Pod.

Remember:
- `envFrom` takes every key as-is and keeps the key names. `env` + `secretKeyRef` picks
  one key and lets you name the variable.
- `k set env deploy/norma-worker --from=secret/norma-db` is NOT the same: it writes one
  `env` entry per key (each with `secretKeyRef`), not an `envFrom` block. When a task says
  "via envFrom", edit the YAML.
- Env vars are read when the container starts. Changing the Secret later doesn't update
  running Pods until they restart.
