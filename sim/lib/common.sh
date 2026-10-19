#!/usr/bin/env bash
# Shared helpers, sourced by every question's setup.sh, check.sh and solve.sh.
COURSE=/opt/course

# --- setup helpers -----------------------------------------------------------

# reset_ns NS... : delete (and wait for) then recreate each namespace.
reset_ns() {
  local ns
  for ns in "$@"; do
    kubectl delete ns "$ns" --ignore-not-found --wait=true --timeout=180s >/dev/null
    kubectl create ns "$ns" >/dev/null
  done
}

# delete_ns NS... : delete namespaces without recreating them.
delete_ns() {
  kubectl delete ns "$@" --ignore-not-found --wait=true --timeout=180s >/dev/null
}

# course_dir N : empty /opt/course/N and print its path.
course_dir() {
  rm -rf "${COURSE:?}/$1"
  mkdir -p "$COURSE/$1"
  echo "$COURSE/$1"
}

# wait_pods NS SELECTOR [TIMEOUT] : wait until matching pods exist and are Ready.
wait_pods() {
  local i
  for i in $(seq 60); do
    [ -n "$(kubectl get pods -n "$1" -l "$2" -o name 2>/dev/null)" ] && break
    sleep 1
  done
  kubectl wait --for=condition=Ready pod -l "$2" -n "$1" --timeout="${3:-120s}" >/dev/null
}

# wait_rollout NS DEPLOYMENT [TIMEOUT]
wait_rollout() {
  kubectl rollout status "deploy/$2" -n "$1" --timeout="${3:-120s}" >/dev/null
}

# --- check helpers -----------------------------------------------------------

PASS=0
TOTAL=0

# check "description" COMMAND... : one scored task; passes when COMMAND exits 0.
check() {
  local desc=$1
  shift
  TOTAL=$((TOTAL + 1))
  if ("$@") >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  \e[32m✔\e[0m %s\n' "$desc"
  else
    printf '  \e[31m✘\e[0m %s\n' "$desc"
  fi
}

# jp ARGS... : `kubectl get ARGS` with errors silenced, e.g. jp pod web -n ns -o jsonpath='{.spec.nodeName}'
jp() { kubectl get "$@" 2>/dev/null; }

# is ACTUAL EXPECTED : string equality.
is() { [ "$1" = "$2" ]; }

# has HAYSTACK NEEDLE : HAYSTACK contains NEEDLE.
has() { grep -qF -- "$2" <<<"$1"; }

# file_has FILE NEEDLE : file exists and contains NEEDLE.
file_has() { [ -f "$1" ] && grep -qF -- "$2" "$1"; }

# finish : report the score to the runner. Must be the last line of check.sh.
finish() { echo "RESULT $PASS $TOTAL"; }
