#!/usr/bin/env bash
# Builds the "nimbus" Helm repo used by the Helm question: webapp chart in two versions.
set -euo pipefail
out=$1
mkdir -p "$out"
cd "$(mktemp -d)"

helm create webapp >/dev/null
sed -i 's/^description:.*/description: Nimbus web application/' webapp/Chart.yaml

sed -i 's/^version:.*/version: 0.1.0/; s/^appVersion:.*/appVersion: "1.27-alpine"/' webapp/Chart.yaml
helm package webapp -d "$out" >/dev/null
sed -i 's/^version:.*/version: 0.2.0/; s/^appVersion:.*/appVersion: "1.29-alpine"/' webapp/Chart.yaml
helm package webapp -d "$out" >/dev/null

helm repo index "$out" --url http://localhost:8879
ls "$out"
