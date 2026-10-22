#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
sed -i 's/ROLE=unset/ROLE=auditor/' /opt/course/11/image/Dockerfile

# Images are built on the build host (podman), which shares /opt/course.
ssh ckad-build 'cd /opt/course/11/image &&
  podman build --build-arg BUILD=v1 -t localhost:5000/nimbus-auditor:v1 -t localhost:5000/nimbus-auditor:latest . &&
  podman push localhost:5000/nimbus-auditor:v1 &&
  podman push localhost:5000/nimbus-auditor:latest &&
  podman save -o /opt/course/11/nimbus-auditor-v1.tar localhost:5000/nimbus-auditor:v1'

kubectl run auditor -n polaris --image=localhost:5000/nimbus-auditor:v1
kubectl wait --for=condition=Ready pod/auditor -n polaris --timeout=120s
sleep 2
kubectl logs auditor -n polaris >/opt/course/11/logs
