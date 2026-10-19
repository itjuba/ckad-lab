#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod lacerta-web -n lacerta"

init_ok() {
  is "$(jp $P -o jsonpath='{.spec.initContainers[?(@.name=="fetch")].image}')" "busybox:1.37" &&
    is "$(jp $P -o jsonpath='{.spec.initContainers[?(@.name=="fetch")].volumeMounts[?(@.name=="content")].mountPath}')" "/work"
}
check "init container fetch (busybox:1.37) mounts content at /work" init_ok

web_ok() {
  is "$(jp $P -o jsonpath='{.spec.containers[?(@.name=="web")].image}')" "nginx:1.29-alpine" &&
    is "$(jp $P -o jsonpath='{.spec.containers[?(@.name=="web")].volumeMounts[?(@.name=="content")].mountPath}')" "/usr/share/nginx/html"
}
check "container web (nginx:1.29-alpine) mounts content at /usr/share/nginx/html" web_ok
check "volume content is an emptyDir" has "$(jp $P -o jsonpath='{.spec.volumes[?(@.name=="content")].emptyDir}')" "{"
check "Pod lacerta-web is Ready" is "$(jp $P -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" "True"

serves() { kubectl exec -n lacerta lacerta-web -c web -- wget -qO- http://localhost 2>/dev/null | grep -qF "<h1>Lacerta</h1>"; }
check "nginx serves <h1>Lacerta</h1>" serves
check "index.html holds the response" file_has "$COURSE/35/index.html" "<h1>Lacerta</h1>"

tmp_gone() { [ -s "$COURSE/35/index.html" ] && is "$(jp pods -n lacerta -o name | grep -v '^pod/lacerta-web$')" ""; }
check "temporary Pod is gone" tmp_gone

finish
