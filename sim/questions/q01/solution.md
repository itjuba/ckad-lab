# Solution 1

```bash
# 1. -l with only a key matches "label exists, any value"
k get ns -l nimbus.io/team                    # look first
k get ns -l nimbus.io/team --no-headers | awk '{print $1}' > /opt/course/1/team-namespaces
#   -o name also works here, but it prints namespace/<name>. When a task asks for
#   names, write bare names.

# 2. -A = all namespaces, --no-headers so wc counts only pods
k get pods -A -l tier=frontend --no-headers | wc -l > /opt/course/1/frontend-pods

# 3. Annotations can't be used as selectors, so search the describe output
k describe pods -A | less
#   type /primary and press Enter: less jumps to "nimbus.io/role: primary"
#   scroll up a few lines to read that Pod's Name: and Node:, then press q
echo <node-name> > /opt/course/1/primary-node
```

Remember:
- `-l key` means the label exists, `-l key=value` matches the value, and `-l '!key'` means the label is missing.
- Annotations can't be selected with `-l`. Read them with `k describe` (plus `grep`), or show
  them as a column: `-o custom-columns=NAME:.metadata.name,ROLE:.metadata.annotations.nimbus\\.io/role,NODE:.spec.nodeName`.
- Answer files hold only the answer: no headers, no extra columns.
