#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod greeter -n mensa"
C='{.spec.containers[0]'

check "Pod greeter exists in mensa with label team=mensa" is "$(jp $P -o jsonpath='{.metadata.labels.team}')" "mensa"
check "container greeter uses busybox:1.37" is "$(jp $P -o jsonpath="$C.name} $C.image}")" "greeter busybox:1.37"

env_ok() {
  is "$(jp $P -o jsonpath="$C.env[?(@.name==\"GREETING\")].value}")" "hello" &&
    is "$(jp $P -o jsonpath="$C.env[?(@.name==\"TARGET\")].value}")" "ckad"
}
check "env GREETING=hello and TARGET=ckad" env_ok

split_ok() {
  is "$(jp $P -o jsonpath="$C.command}")" '["sh","-c"]' &&
    has "$(jp $P -o jsonpath="$C.args}")" 'echo' &&
    has "$(jp $P -o jsonpath="$C.args}")" 'sleep 3600'
}
check "command is [sh, -c] and the script is in args" split_ok
check "Pod is Running" is "$(jp $P -o jsonpath='{.status.phase}')" "Running"
check "greeting.log holds the Pod's output" file_has "$COURSE/29/greeting.log" "hello, ckad"
check "target holds the output of printenv TARGET" is "$(tr -d '[:space:]' <"$COURSE/29/target" 2>/dev/null)" "ckad"

finish
