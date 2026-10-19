#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 17)/kustomize
delete_ns sirius-staging
reset_ns sirius
mkdir -p "$D/base" "$D/overlays/dev"

cat >"$D/base/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sirius-api
  labels:
    app: sirius-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sirius-api
  template:
    metadata:
      labels:
        app: sirius-api
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
EOF

cat >"$D/base/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: sirius-api
  labels:
    app: sirius-api
spec:
  selector:
    app: sirius-api
  ports:
  - port: 80
    targetPort: 80
EOF

cat >"$D/base/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

cat >"$D/overlays/dev/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: sirius
resources:
- ../../base
labels:
- pairs:
    env: dev
patches:
- path: app-env.yaml
EOF

cat >"$D/overlays/dev/app-env.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sirius-api
spec:
  template:
    spec:
      containers:
      - name: api
        env:
        - name: APP_ENV
          value: dev
EOF

kubectl apply -k "$D/overlays/dev"
wait_rollout sirius sirius-api
