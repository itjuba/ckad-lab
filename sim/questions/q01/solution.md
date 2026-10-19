# Solution 1

```bash
# 1. -l with only a key matches "label exists, any value"
k get ns -l nimbus.io/team                    # look first
k get ns -l nimbus.io/team -o name > /opt/course/1/team-namespaces
#   -o name prints namespace/<name>, which is fine here. For bare names:
k get ns -l nimbus.io/team --no-headers | awk '{print $1}' > /opt/course/1/team-namespaces

# 2. -A = all namespaces, --no-headers so wc counts only pods
k get pods -A -l tier=frontend --no-headers | wc -l > /opt/course/1/frontend-pods

# 3. Annotations can't be used as selectors, so read them from describe
k describe pods -A | grep -E '^Name:|^Node:|nimbus.io/role'
#   the Name/Node lines just above "nimbus.io/role=primary" are the ones you want
echo <node-name> > /opt/course/1/primary-node
```

Remember:
- `-l key` means the label exists, `-l key=value` matches the value, and `-l '!key'` means the label is missing.
- Annotations can't be selected with `-l`. Read them with `k describe` (plus `grep`), or show
  them as a column: `-o custom-columns=NAME:.metadata.name,ROLE:.metadata.annotations.nimbus\\.io/role,NODE:.spec.nodeName`.
- Answer files hold only the answer: no headers, no extra columns.
