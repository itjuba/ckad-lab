# Solution 31

All five steps have an imperative command. No YAML needed:

```bash
# 1. create (--port sets containerPort 80)
k create deploy octans-web -n octans --image=nginx:1.28-alpine --replicas=2 --port=80

# 2. scale
k scale deploy octans-web -n octans --replicas=4

# 3. update the image: container name = image name without the tag (here: nginx)
k describe deploy octans-web -n octans | grep -A2 Containers
k set image deploy/octans-web -n octans nginx=nginx:1.29-alpine
k rollout status deploy/octans-web -n octans

# 4.
k rollout history deploy/octans-web -n octans > /opt/course/31/history
cat /opt/course/31/history                     # REVISION 1 and 2

# 5. port = Service port, target-port = container port
k expose deploy octans-web -n octans --port=8080 --target-port=80
k get endpoints octans-web -n octans           # 4 Pod IPs on port 80
```

Remember:
- `k set image` needs the **container** name, not the Deployment name. `kubectl create
  deploy` names the container after the image (`nginx`).
- Scaling doesn't create a new revision. Only changes to the Pod template (image, env,
  labels…) do. That's why the history shows 2 revisions, not 3.
- `k expose` copies the selector from the Deployment, so the endpoints are right
  automatically.
