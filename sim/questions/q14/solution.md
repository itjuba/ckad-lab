# Solution 14

```bash
# 1. Single quotes stop the shell from treating ! specially
k create secret generic db-credentials -n pegasus \
  --from-literal=user=pegasus-app --from-literal='password=Sup3rS3cret!'

# 2. The manifest says namespace: default. Fix that first, because
#    "k apply -n pegasus" fails when the file names a different namespace.
vim /opt/course/14/tls-bundle.yaml          # namespace: default  ->  namespace: pegasus
k apply -f /opt/course/14/tls-bundle.yaml
k get secret -n pegasus

# 3.
k run db-client -n pegasus --image=busybox:1.37 $do --command -- sh -c "sleep 1d" > 14.yaml
vim 14.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-client
  namespace: pegasus
spec:
  containers:
  - name: db-client
    image: busybox:1.37
    command: ["sh", "-c", "sleep 1d"]
    env:                                # added
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: user
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:                       # added
    - name: tls
      mountPath: /etc/tls
      readOnly: true
  volumes:                              # added
  - name: tls
    secret:
      secretName: tls-bundle
      items:                            # only these keys get projected
      - key: ca.crt
        path: ca.pem                    # file name inside the mount
        mode: 0400                      # octal; or use defaultMode: 0400
```

```bash
k apply -f 14.yaml
k exec -n pegasus db-client -- printenv DB_USER
k exec -n pegasus db-client -- ls -l /etc/tls/
k exec -n pegasus db-client -- stat -L -c %a /etc/tls/ca.pem    # 400
```

Remember:
- Once you list `items`, keys that aren't listed don't appear in the mount.
- Files in a Secret volume are symlinks, so use `stat -L` to see the real file's mode.
- Write `0400` with the leading 0 so YAML reads it as octal. Plain `400` is a decimal number and gives the wrong mode.
