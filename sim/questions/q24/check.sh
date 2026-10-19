#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
DS="ds node-agent -n vela"
T='{.spec.template.spec'

check "DaemonSet node-agent exists in vela" jp $DS
check "Pods are labelled app=node-agent" is "$(jp $DS -o jsonpath="{.spec.template.metadata.labels.app}")" "node-agent"
check "tolerates node-role.kubernetes.io/control-plane:NoSchedule" \
  has "$(jp $DS -o jsonpath="$T.tolerations[?(@.key==\"node-role.kubernetes.io/control-plane\")].effect}")" "NoSchedule"
check "emptyDir volume config" has "$(jp $DS -o jsonpath="$T.volumes[?(@.name==\"config\")].emptyDir}")" "{"

init_ok() {
  is "$(jp $DS -o jsonpath="$T.initContainers[?(@.name==\"init-config\")].image}")" "busybox:1.37" &&
    is "$(jp $DS -o jsonpath="$T.initContainers[?(@.name==\"init-config\")].volumeMounts[?(@.name==\"config\")].mountPath}")" "/config"
}
check "init container init-config (busybox:1.37) mounts config at /config" init_ok
check "NODE_NAME comes from the Downward API (spec.nodeName)" \
  is "$(jp $DS -o jsonpath="$T.initContainers[?(@.name==\"init-config\")].env[?(@.name==\"NODE_NAME\")].valueFrom.fieldRef.fieldPath}")" "spec.nodeName"

agent_ok() {
  is "$(jp $DS -o jsonpath="$T.containers[?(@.name==\"agent\")].image}")" "busybox:1.37" &&
    is "$(jp $DS -o jsonpath="$T.containers[?(@.name==\"agent\")].volumeMounts[?(@.name==\"config\")].mountPath}")" "/config"
}
check "container agent (busybox:1.37) mounts config at /config" agent_ok

all_nodes() {
  local nodes ready
  nodes=$(jp nodes --no-headers | wc -l)
  ready=$(jp $DS -o jsonpath='{.status.numberReady}')
  [ "$ready" = "$nodes" ] && [ "$(jp $DS -o jsonpath='{.status.desiredNumberScheduled}')" = "$nodes" ]
}
check "a ready Pod runs on every node" all_nodes

logs_ok() {
  local pod
  pod=$(jp pods -n vela -l app=node-agent --field-selector spec.nodeName=k3d-ckad-agent-0 -o jsonpath='{.items[0].metadata.name}')
  [ -n "$pod" ] && kubectl logs -n vela "$pod" -c agent | grep -qx 'node=k3d-ckad-agent-0' &&
    file_has "$COURSE/24/agent.log" "node=k3d-ckad-agent-0"
}
check "agent.log holds node=k3d-ckad-agent-0 from the agent container" logs_ok

finish
