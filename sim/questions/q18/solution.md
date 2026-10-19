# Solution 18

Start by comparing the Service with what the Pods actually listen on:

```bash
k get svc,ep -n antares
k get deploy antares-api -n antares -o yaml | grep -A3 ports     # containerPort: 80
k get svc antares-api -n antares -o yaml | grep -A4 ports        # targetPort: 8080, wrong
```

The Service has endpoints, but it sends traffic to port 8080, where nothing is listening.

```bash
k edit svc antares-api -n antares
```

```yaml
  ports:
  - port: 80
    targetPort: 80          # was: 8080
```

```bash
# Quick test from inside the cluster
k run tmp -n antares --rm -it --restart=Never --image=busybox:1.37 -- wget -qO- antares-api

# Ingress: generate it, then check
k create ingress antares-ingress -n antares --class=traefik \
  --rule="shop.nimbus.local/shop*=antares-shop:8080" \
  --rule="shop.nimbus.local/api*=antares-api:80" $do > 18.yaml
cat 18.yaml                 # path: /shop and /api, pathType: Prefix (the * gives Prefix)
k apply -f 18.yaml
k describe ingress antares-ingress -n antares

curl -s -H 'Host: shop.nimbus.local' http://k3d-ckad-server-0/shop    # "Name: shop"
curl -s -H 'Host: shop.nimbus.local' http://k3d-ckad-server-0/api > /opt/course/18/api-response
cat /opt/course/18/api-response    # JSON with "name":"api" (whoami serves /api as JSON)
```

Remember:
- An Ingress backend uses the **Service** port (8080 for shop), not the container port.
- Endpoints existing doesn't mean the Service works. Endpoints only show which Pods match the selector, not whether `targetPort` is correct.
- In `k create ingress`, `path*` gives `pathType: Prefix` and a path without `*` gives `Exact`.
- The controller can take a few seconds to pick up a new Ingress. If you get a 404 straight away, retry the curl.
