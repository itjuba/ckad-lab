#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl patch svc antares-api -n antares --type=json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'

kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: antares-ingress
  namespace: antares
spec:
  ingressClassName: traefik
  rules:
  - host: shop.nimbus.local
    http:
      paths:
      - path: /shop
        pathType: Prefix
        backend:
          service:
            name: antares-shop
            port:
              number: 8080
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: antares-api
            port:
              number: 80
EOF

for _ in $(seq 30); do
  curl -s -m 5 -H 'Host: shop.nimbus.local' http://k3d-ckad-server-0/api >/opt/course/18/api-response
  grep -q '"name":"api"' /opt/course/18/api-response && break
  sleep 2
done
