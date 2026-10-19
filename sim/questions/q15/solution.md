# Solution 15

```bash
# 1. --from-env-file makes one key per line. --from-file would make a single
#    key called "gateway.env". kubectl create has no --immutable flag, so add it by hand.
k create cm gateway-config-v2 -n carina --from-env-file=/opt/course/15/gateway.env $do > 15-cm.yaml
echo 'immutable: true' >> 15-cm.yaml
k apply -f 15-cm.yaml
k get cm gateway-config-v2 -n carina -o yaml

# 2.
k edit deploy carina-gateway -n carina
```

```yaml
        envFrom:
        - configMapRef:
            name: gateway-config-v2      # was: gateway-config-v1
```

```bash
k rollout status deploy carina-gateway -n carina
k get pods -n carina                     # use a Pod from the new ReplicaSet (youngest AGE)

# 3.
k exec -n carina <new-pod> -- sh -c 'env | grep ^GW_ | sort' > /opt/course/15/env.txt
cat /opt/course/15/env.txt

# 4.
k delete cm gateway-config-v1 -n carina
```

Remember:
- Pods read env vars only at startup. Changing a ConfigMap never updates running Pods, but changing the Deployment's Pod template triggers a rollout.
- Once a ConfigMap is immutable, you can't change its data or set it back to mutable. The only way to change it is to delete it and create it again. That's why versioned names like `-v2` are common.
- Quote the command in `sh -c '...'`. Without quotes, the `|` runs on your terminal instead of inside the container.
