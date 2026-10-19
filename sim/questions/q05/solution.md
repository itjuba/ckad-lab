# Solution 5

```bash
# 1. Find the Secret whose annotation points at orion-ci (orion-web-token is the wrong one)
k -n orion get secret
k -n orion describe secret orion-ci-token              # describe already shows it decoded
k -n orion describe secret orion-ci-token | grep '^token' | awk '{print $2}' > /opt/course/5/token
#   or decode it yourself: k get secret ... -o yaml, copy .data.token, then
#   echo <value> | base64 -d > /opt/course/5/token

# 2. Pods and pods/log need different verbs, so write the Role as YAML
k -n orion create role pod-reader --verb=get,list,watch --resource=pods $do > 5-role.yaml
vim 5-role.yaml
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: orion
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]              # added: logs are the pods/log subresource
  resources: ["pods/log"]
  verbs: ["get"]
```

```bash
k apply -f 5-role.yaml
k -n orion create rolebinding orion-ci-pod-reader --role=pod-reader --serviceaccount=orion:orion-ci

# 3. --as impersonates the ServiceAccount
k auth can-i delete pods -n orion --as=system:serviceaccount:orion:orion-ci > /opt/course/5/can-delete
k auth can-i get pods --subresource=log -n orion --as=system:serviceaccount:orion:orion-ci   # yes
```

Remember:
- Secret `.data` values are base64 encoded. `describe secret` prints a
  ServiceAccount token decoded, but for other Secrets it only shows sizes.
- `--serviceaccount` takes `namespace:name`. The `--as` username is
  `system:serviceaccount:<namespace>:<name>`.
