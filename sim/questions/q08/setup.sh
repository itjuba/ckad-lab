#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 8 >/dev/null
reset_ns perseus

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: perseus-web
  namespace: perseus
  annotations:
    kubernetes.io/change-cause: initial release 1.27
spec:
  replicas: 3
  selector:
    matchLabels:
      app: perseus-web
  template:
    metadata:
      labels:
        app: perseus-web
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
EOF
wait_rollout perseus perseus-web

# update IMAGE CAUSE : change image and change-cause in one request, so each
# revision records its own cause.
update() {
  kubectl patch deploy perseus-web -n perseus -p \
    "{\"metadata\":{\"annotations\":{\"kubernetes.io/change-cause\":\"$2\"}},\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"web\",\"image\":\"$1\"}]}}}}"
}
update nginx:1.28-alpine "upgrade to 1.28"
wait_rollout perseus perseus-web
update nginx:1.99-missing "upgrade to 1.99"

# Revision 3 can never become available: its image doesn't exist.
kubectl wait --for=jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'=3 deploy/perseus-web -n perseus --timeout=60s >/dev/null
