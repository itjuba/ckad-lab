#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
cd /opt/course/11/image || exit 1
sed -i 's/ROLE=unset/ROLE=auditor/' Dockerfile
docker build --build-arg BUILD=v1 -t localhost:5000/nimbus-auditor:v1 -t localhost:5000/nimbus-auditor:latest .
docker push localhost:5000/nimbus-auditor:v1
docker push localhost:5000/nimbus-auditor:latest

kubectl run auditor -n polaris --image=localhost:5000/nimbus-auditor:v1
kubectl wait --for=condition=Ready pod/auditor -n polaris --timeout=120s
sleep 2
kubectl logs auditor -n polaris >/opt/course/11/logs
