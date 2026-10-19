# Solution 22

A Service sends traffic to every ready Pod its selector matches. Give the v2
Pods the label the Service selects (`app=castor`), and the replica counts decide
how traffic is split.

```bash
k -n castor describe svc castor | grep Selector                    # app=castor
k -n castor get pod --show-labels                                   # v1 Pods: app=castor,version=v1
k -n castor create deploy castor-v2 --image=traefik/whoami:v1.11 --replicas=1 $do > 22.yaml
vim 22.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: castor-v2
  namespace: castor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: castor                # was: castor-v2
      version: v2                # added
  template:
    metadata:
      labels:
        app: castor              # was: castor-v2 (this is what the Service matches)
        version: v2              # added
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=v2"]      # added
```

`create deploy ... -- <cmd>` would set `command` and replace the image's entrypoint,
so add `args` in vim instead.

```bash
k apply -f 22.yaml
k -n castor scale deploy castor-v1 --replicas=3          # 3 + 1 = 4 Pods, 25% v2
k -n castor get endpointslices -l kubernetes.io/service-name=castor

k -n castor run tmp --rm -i --restart=Never --image=busybox:1.37 -- \
  sh -c 'for i in $(seq 20); do wget -qO- http://castor; done' | grep '^Name:' > /opt/course/22/responses
cat /opt/course/22/responses
```

Remember:
- Each Deployment needs its own selector (`version: v1` or `version: v2`). If both used only `app=castor`, each one would treat the other's Pods as its own.
- To finish the canary, scale v2 up and v1 down. To roll back, scale v2 to 0. The Service never changes.
