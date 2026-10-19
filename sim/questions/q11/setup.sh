#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 11)
reset_ns polaris
mkdir -p "$D/image"

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
