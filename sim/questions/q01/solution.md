# Solution 1

```bash
# 1. -l with only a key matches "label exists, any value"
k get ns -l nimbus.io/team -o name            # look first
k get ns -l nimbus.io/team -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' > /opt/course/1/team-namespaces

# 2. -A = all namespaces, --no-headers so wc counts only pods
k get pods -A -l tier=frontend --no-headers | wc -l > /opt/course/1/frontend-pods

# 3. Annotations can't be used as selectors, so search the output
k get pods -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,ROLE:.metadata.annotations.nimbus\\.io/role,NODE:.spec.nodeName
echo <node-name> > /opt/course/1/primary-node
```

Remember:
- `-l key` means the label exists, `-l key=value` matches the value, and `-l '!key'` means the label is missing.
- Annotations can't be selected with `-l`. Use `custom-columns`, `jsonpath`, or `describe | grep`.
