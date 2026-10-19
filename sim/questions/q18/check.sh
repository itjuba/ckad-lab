#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
NS=antares
I="ingress antares-ingress -n $NS"
URL=http://k3d-ckad-server-0
HOST=shop.nimbus.local

api_fixed() {
  local slice
  slice=$(jp endpointslice -n $NS -l kubernetes.io/service-name=antares-api \
    -o jsonpath='{.items[*].ports[*].port} {.items[*].endpoints[*].addresses[0]}')
  [ "${slice%% *}" = "80" ] && [ -n "${slice#* }" ] &&
    [ "$(jp deploy antares-api -n $NS -o jsonpath='{.spec.template.spec.containers[0].args}')" = '["--name=api"]' ]
}
check "Service antares-api sends traffic to port 80 of the api Pods (Deployment unchanged)" api_fixed

check "Ingress antares-ingress uses IngressClass traefik" is "$(jp $I -o jsonpath='{.spec.ingressClassName}')" "traefik"

route() { # route PATH -> "pathType service port"
  jp $I -o jsonpath="{.spec.rules[?(@.host==\"$HOST\")].http.paths[?(@.path==\"$1\")].pathType} {.spec.rules[?(@.host==\"$HOST\")].http.paths[?(@.path==\"$1\")].backend.service.name} {.spec.rules[?(@.host==\"$HOST\")].http.paths[?(@.path==\"$1\")].backend.service.port.number}"
}
check "host $HOST, /shop (Prefix) -> antares-shop:8080" is "$(route /shop)" "Prefix antares-shop 8080"
check "host $HOST, /api (Prefix) -> antares-api:80" is "$(route /api)" "Prefix antares-api 80"

# whoami answers in text ("Name: api"), except on /api where it answers in JSON ("name":"api").
from_backend() { grep -qE "^Name: $1|\"name\":\"$1\""; }
live() { curl -s -m 5 -H "Host: $HOST" "$URL$1" | from_backend "$2"; }
check "curl $HOST/shop answers from the shop backend" live /shop shop
check "curl $HOST/api answers from the api backend" live /api api

check "/opt/course/18/api-response contains the api backend response" \
  bash -c "[ -f '$COURSE/18/api-response' ] && grep -qE '^Name: api|\"name\":\"api\"' '$COURSE/18/api-response'"

finish
