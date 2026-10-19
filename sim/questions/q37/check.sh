#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
CM="cm crater-config -n crater"
P="pod crater-app -n crater"
SRC=$COURSE/37/config
in_pod() { kubectl exec -n crater crater-app -- "$@" 2>/dev/null; }

keys() { jp $CM -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'; }
check "crater-config has exactly the keys app.properties and logging.properties" \
  is "$(keys)" "$(printf 'app.properties\nlogging.properties')"

content_ok() {
  is "$(jp $CM -o go-template='{{index .data "app.properties"}}')" "$(cat "$SRC/app.properties")" &&
    is "$(jp $CM -o go-template='{{index .data "logging.properties"}}')" "$(cat "$SRC/logging.properties")"
}
check "the keys hold the contents of the two files" content_ok

check "Pod crater-app (busybox:1.37) is Running" \
  is "$(jp $P -o jsonpath='{.spec.containers[0].image}/{.status.phase}')" "busybox:1.37/Running"

whole_cm() {
  local vol
  vol=$(jp $P -o jsonpath='{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/crater")].name}')
  [ -n "$vol" ] &&
    is "$(jp $P -o jsonpath='{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/crater")].readOnly}')" "true" &&
    is "$(jp $P -o jsonpath="{.spec.volumes[?(@.name==\"$vol\")].configMap.name}")" "crater-config" &&
    is "$(in_pod ls /etc/crater | sort | tr '\n' ' ')" "app.properties logging.properties "
}
check "the whole ConfigMap is mounted read-only at /etc/crater" whole_cm

log_conf() {
  is "$(in_pod ls /etc/logging)" "log.conf" &&
    is "$(in_pod cat /etc/logging/log.conf)" "$(cat "$SRC/logging.properties")"
}
check "only logging.properties is mounted, as /etc/logging/log.conf" log_conf

check "app.properties.out holds the file as seen in the Pod" \
  is "$(cat "$COURSE/37/app.properties.out" 2>/dev/null)" "$(cat "$SRC/app.properties")"

finish
