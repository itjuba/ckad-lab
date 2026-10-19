#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
NS=pegasus
P="pod db-client -n $NS"
podexec() { kubectl exec -n $NS db-client -- "$@" 2>/dev/null; }
secret_val() { jp secret "$1" -n $NS -o jsonpath="{.data.$2}" | base64 -d; }
env_ref() { jp $P -o jsonpath="{.spec.containers[0].env[?(@.name==\"$1\")].valueFrom.secretKeyRef.name}/{.spec.containers[0].env[?(@.name==\"$1\")].valueFrom.secretKeyRef.key}"; }

check "Secret db-credentials has user=pegasus-app and password=Sup3rS3cret!" \
  is "$(secret_val db-credentials user) $(secret_val db-credentials password)" "pegasus-app Sup3rS3cret!"
check "Secret tls-bundle exists in pegasus with key ca.crt" is "$(secret_val tls-bundle 'ca\.crt' | head -1)" "-----BEGIN CERTIFICATE-----"
check "Pod db-client is Running" is "$(jp $P -o jsonpath='{.status.phase}')" "Running"
check "DB_USER and DB_PASSWORD come from Secret db-credentials (secretKeyRef)" \
  is "$(env_ref DB_USER) $(env_ref DB_PASSWORD)" "db-credentials/user db-credentials/password"
check "printenv DB_USER in the Pod prints pegasus-app" is "$(podexec printenv DB_USER)" "pegasus-app"

mount_ro() {
  local vol
  vol=$(jp $P -o jsonpath='{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/tls")].name}')
  [ -n "$vol" ] &&
    [ "$(jp $P -o jsonpath="{.spec.containers[0].volumeMounts[?(@.mountPath==\"/etc/tls\")].readOnly}")" = "true" ] &&
    [ "$(jp $P -o jsonpath="{.spec.volumes[?(@.name==\"$vol\")].secret.secretName}")" = "tls-bundle" ]
}
check "Secret tls-bundle is mounted read-only at /etc/tls" mount_ro

expected_ca=$(secret_val tls-bundle 'ca\.crt')
check "/etc/tls/ca.pem contains the CA certificate" is "$(podexec cat /etc/tls/ca.pem)" "${expected_ca:-missing}"
check "/etc/tls contains only ca.pem (no server.crt)" is "$(podexec ls /etc/tls)" "ca.pem"
check "/etc/tls/ca.pem has file mode 0400" is "$(podexec stat -L -c %a /etc/tls/ca.pem)" "400"

finish
