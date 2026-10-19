#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
  namespace: vela
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: config
        emptyDir: {}
      initContainers:
      - name: init-config
        image: busybox:1.37
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        command: ["sh", "-c", "echo node=$NODE_NAME > /config/agent.conf"]
        volumeMounts:
        - name: config
          mountPath: /config
      containers:
      - name: agent
        image: busybox:1.37
        command: ["sh", "-c", "cat /config/agent.conf; sleep 1d"]
        volumeMounts:
        - name: config
          mountPath: /config
EOF
kubectl rollout status ds/node-agent -n vela --timeout=120s
pod=$(kubectl get pods -n vela -l app=node-agent --field-selector spec.nodeName=k3d-ckad-agent-0 -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n vela "$pod" -c agent >/opt/course/24/agent.log
