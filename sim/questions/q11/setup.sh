#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 11)
reset_ns polaris
mkdir -p "$D/image"
# Start from a clean build host: no image left from a previous attempt (ignore if it's down).
ssh -o ConnectTimeout=5 ckad-build 'podman rmi -f localhost:5000/nimbus-auditor:v1 localhost:5000/nimbus-auditor:latest' >/dev/null 2>&1 || true

cat >"$D/image/Dockerfile" <<'EOF'
FROM busybox:1.37
ARG BUILD=dev
ENV BUILD=$BUILD ROLE=unset
COPY run.sh /run.sh
CMD ["sh", "/run.sh"]
EOF

cat >"$D/image/run.sh" <<'EOF'
#!/bin/sh
while true; do
  echo "nimbus auditor role=$ROLE build=$BUILD"
  sleep 5
done
EOF
