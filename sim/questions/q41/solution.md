# Solution 41

```bash
k create sa reticulum-runner -n reticulum
k set serviceaccount deploy reticulum-app reticulum-runner -n reticulum
k edit deploy reticulum-app -n reticulum
```

```yaml
  template:
    spec:
      serviceAccountName: reticulum-runner      # set by k set serviceaccount
      automountServiceAccountToken: false       # added, Pod template level
      containers:
      - name: nginx
        ...
```

```bash
k rollout status deploy reticulum-app -n reticulum
k get pod -n reticulum                                    # new Pods only

k describe pod -n reticulum -l app=reticulum-app | grep -i "service account"
#   Service Account:  reticulum-runner
echo reticulum-runner > /opt/course/41/sa-name

# verify: no token directory any more
k exec -n reticulum deploy/reticulum-app -- ls /var/run/secrets/kubernetes.io/serviceaccount
#   ls: ... No such file or directory
```

Remember:
- `k set serviceaccount` (short: `k set sa`) changes the Pod template, so a rollout
  follows. You can't change a running Pod's ServiceAccount, only recreate the Pod.
- `automountServiceAccountToken: false` can sit on the Pod spec or on the ServiceAccount.
  The Pod spec setting wins.
- In the YAML, the field is `serviceAccountName`. The older `serviceAccount` field is
  deprecated.
