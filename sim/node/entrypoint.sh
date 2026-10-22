#!/usr/bin/env bash
# Build host start: the key pair the exam terminal uses for `ssh ckad-build` (kept in the
# shared /ckad-state/ssh), a localhost:5000 forward to the image registry, then sshd.
set -e
mkdir -p /ckad-state/ssh /root/.ssh
chmod 700 /root/.ssh
[ -f /ckad-state/ssh/id_ed25519 ] ||
  ssh-keygen -q -t ed25519 -N '' -C candidate@ckad -f /ckad-state/ssh/id_ed25519
cp /ckad-state/ssh/id_ed25519.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
ssh-keygen -A

socat TCP-LISTEN:5000,fork,reuseaddr,bind=127.0.0.1 "TCP:${CKAD_REGISTRY:-k3d-ckad-registry}:5000" &
exec /usr/sbin/sshd -D -e
