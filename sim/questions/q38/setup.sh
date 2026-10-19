#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 38)
reset_ns norma

# No trailing newline, so the env var holds exactly the key.
printf 'nrm-4f7c1a9e2b6d8035' >"$D/api-key.txt"
cat >"$D/db.env" <<'EOF'
DB_HOST=db.norma.svc
DB_PORT=5432
EOF
