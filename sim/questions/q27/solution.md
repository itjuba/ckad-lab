# Solution 27

Start from the symptom: a Service without endpoints means its selector matches no Pods.

```bash
k get svc,endpoints -n columba               # ENDPOINTS: <none>
k get svc columba-web -n columba -o yaml | grep -A3 selector
k get pod -n columba --show-labels           # app=columba-web, team=columba
```

The selector says `app=columba-website`, but the Pods are labelled `app=columba-web`.

```bash
echo "Service selector app=columba-website doesn't match Pod label app=columba-web" > /opt/course/27/cause
k edit svc columba-web -n columba
```

```yaml
spec:
  type: NodePort                 # was: ClusterIP
  selector:
    app: columba-web             # was: columba-website
    team: columba
  ports:
  - port: 80
    targetPort: web
    nodePort: 30780              # added
```

```bash
k get endpoints columba-web -n columba       # two Pod IPs
curl -s http://k3d-ckad-server-0:30780 > /opt/course/27/nodeport.html
```

Remember:
- Check in this order: endpoints, then selector vs Pod labels, then `targetPort` vs
  `containerPort` (or the port name).
- A NodePort Service still has its ClusterIP and `port`. `nodePort` only adds the port
  opened on every node.
- `k expose` copies the selector from the Deployment. A selector typed by hand is the
  usual source of this bug.
