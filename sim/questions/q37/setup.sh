#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 37)
reset_ns crater

mkdir -p "$D/config"
cat >"$D/config/app.properties" <<'EOF'
app.name=crater
app.port=8080
feature.search=enabled
EOF
cat >"$D/config/logging.properties" <<'EOF'
log.level=INFO
log.format=json
EOF
cat >"$D/config/notes.txt" <<'EOF'
Internal notes: don't ship this file to the cluster.
EOF
