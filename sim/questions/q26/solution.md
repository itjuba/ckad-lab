# Solution 26

Green is a second Deployment. The switch is a single change to the Service selector.

```bash
k create deploy checkout-green -n tucana --image=traefik/whoami:v1.11 --replicas=3 $do > 26.yaml
vim 26.yaml
```

```yaml
spec:
  replicas: 3
  selector:
    matchLabels:
      app: checkout
      version: green              # changed
  template:
    metadata:
      labels:
        app: checkout
        version: green            # changed
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=green"]    # added
```

```bash
k apply -f 26.yaml
k rollout status deploy checkout-green -n tucana     # wait until 3/3 ready

# switch: point the selector at green
k edit svc checkout -n tucana                        # version: blue -> version: green
k get endpoints checkout -n tucana                   # only green Pod IPs now

k run tmp -n tucana --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://checkout > /opt/course/26/after-switch
cat /opt/course/26/after-switch                      # Name: green

k scale deploy checkout-blue -n tucana --replicas=0
```

Remember:
- Blue/green = two full Deployments plus one Service. Canary = both versions behind the
  same selector at the same time, with replica counts setting the split.
- To roll back, scale blue up again and set the selector back to `version: blue`.
- `kubectl run --rm -i` may append `pod "tmp" deleted` to the output. Remove that line
  from the file if you want it clean.
