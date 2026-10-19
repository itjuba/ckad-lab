#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 14)
reset_ns pegasus
kubectl delete secret tls-bundle -n default --ignore-not-found >/dev/null

ca=$(printf -- '-----BEGIN CERTIFICATE-----\nMIIBpegasusNimbusRootCAforPracticeOnly0001AbCdEf\n-----END CERTIFICATE-----\n' | base64 -w0)
crt=$(printf -- '-----BEGIN CERTIFICATE-----\nMIIBpegasusDbServerCertForPracticeOnly0002GhIjKl\n-----END CERTIFICATE-----\n' | base64 -w0)

cat >"$D/tls-bundle.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tls-bundle
  namespace: default
  labels:
    app: db-client
type: Opaque
data:
  ca.crt: $ca
  server.crt: $crt
EOF
