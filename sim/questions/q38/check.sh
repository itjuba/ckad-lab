#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy norma-worker -n norma"
KEY=$(cat "$COURSE/38/api-key.txt" 2>/dev/null)
in_pod() { kubectl exec -n norma deploy/norma-worker -- "$@" 2>/dev/null; }

check "norma-api holds api-key.txt under the key api-key" \
  is "$(jp secret norma-api -n norma -o go-template='{{index .data "api-key" | base64decode}}')" "$KEY"
check "norma-db has the keys DB_HOST and DB_PORT from db.env" \
  is "$(jp secret norma-db -n norma -o go-template='{{range $k, $v := .data}}{{$k}}={{$v | base64decode}}{{"\n"}}{{end}}')" \
  "$(printf 'DB_HOST=db.norma.svc\nDB_PORT=5432')"

check "norma-worker loads all of norma-db with envFrom" \
  has "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].secretRef.name}')" "norma-db"
check "API_KEY comes from key api-key of Secret norma-api" \
  is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="API_KEY")].valueFrom.secretKeyRef.name}/{.spec.template.spec.containers[0].env[?(@.name=="API_KEY")].valueFrom.secretKeyRef.key}')" "norma-api/api-key"
check "norma-worker (busybox:1.37) has 1 available replica" \
  is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].image}/{.status.availableReplicas}')" "busybox:1.37/1"

live_env() {
  is "$(in_pod printenv DB_HOST)" "db.norma.svc" && is "$(in_pod printenv DB_PORT)" "5432" &&
    is "$(in_pod printenv API_KEY)" "$KEY"
}
check "the running Pod sees DB_HOST, DB_PORT and API_KEY" live_env

env_file() {
  local f=$COURSE/38/env.txt
  file_has "$f" "DB_HOST=db.norma.svc" && file_has "$f" "DB_PORT=5432" && file_has "$f" "API_KEY=$KEY"
}
check "env.txt holds the three variables" env_file

finish
