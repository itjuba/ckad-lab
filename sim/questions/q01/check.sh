#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$COURSE/1

expected_ns=$(jp ns -l nimbus.io/team -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)
actual_ns=$( [ -f "$D/team-namespaces" ] && sed 's/^namespace\///; s/[[:space:]]*$//; /^$/d' "$D/team-namespaces" | sort)
check "team-namespaces lists exactly the labelled namespaces" is "$actual_ns" "$expected_ns"

expected_count=$(jp pods -A -l tier=frontend -o name | wc -l)
check "frontend-pods contains $expected_count" is "$(tr -d '[:space:]' <"$D/frontend-pods" 2>/dev/null)" "$expected_count"

expected_node=$(jp pod search-ui -n nimbus-search -o jsonpath='{.spec.nodeName}')
check "primary-node contains the node of the primary pod" is "$(tr -d '[:space:]' <"$D/primary-node" 2>/dev/null | sed 's|^node/||')" "$expected_node"

finish
