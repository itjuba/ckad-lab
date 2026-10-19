#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
echo "Service selector app=columba-website doesn't match the Pod label app=columba-web" >/opt/course/27/cause
kubectl patch svc columba-web -n columba --type=merge -p \
  '{"spec":{"type":"NodePort","selector":{"app":"columba-web","team":"columba"},"ports":[{"port":80,"targetPort":"web","nodePort":30780}]}}'
for _ in $(seq 30); do
  curl -s -m 3 http://k3d-ckad-server-0:30780 >/opt/course/27/nodeport.html && grep -q nginx /opt/course/27/nodeport.html && break
  sleep 1
done
