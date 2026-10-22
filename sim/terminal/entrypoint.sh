#!/usr/bin/env bash
# Container start: build the kubeconfig (one context per cluster), set up ssh to the build
# host, start the chart repo and the web UI, idle. With arguments (Docker Compose's one-shot
# setup) it runs them instead of the web UI.
mkdir -p /root/.kube /opt/course
bash /ckad/terminal/kubeconfig.sh /root/.kube/config || echo "entrypoint: no kubeconfig built" >&2

# The build host (ckad-build) generates the key pair for `ssh ckad-build` into the shared
# /ckad-state/ssh when it first starts; give it a moment if it's still coming up.
for _ in $(seq 30); do [ -f /ckad-state/ssh/id_ed25519 ] && break; sleep 1; done
if [ -f /ckad-state/ssh/id_ed25519 ]; then
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  cp /ckad-state/ssh/id_ed25519 /root/.ssh/id_ed25519 && chmod 600 /root/.ssh/id_ed25519
  cat >/root/.ssh/config <<'EOF'
Host ckad-build
  User root
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOF
  chmod 600 /root/.ssh/config
else
  echo "entrypoint: no ssh key in /ckad-state/ssh; is the build host running?" >&2
fi

python3 -m http.server 8879 --bind 127.0.0.1 --directory /srv/charts >/dev/null 2>&1 &
[ $# -gt 0 ] && exec "$@"
if [ -x /usr/local/bin/ckad-ui ]; then
  CKAD_HOME=/ckad /usr/local/bin/ckad-ui >/tmp/ckad-ui.log 2>&1 &
fi
exec sleep infinity
