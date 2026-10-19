# ServiceAccount token and least-privilege RBAC

Namespace: `orion`

Team Orion's CI system authenticates as the ServiceAccount `orion-ci`. It
should only be able to read Pods and their logs.

1. A Secret in Namespace `orion` holds the API token of ServiceAccount
   `orion-ci`. Write the **base64-decoded** token into `/opt/course/5/token`.

2. Create a Role `pod-reader` in Namespace `orion` that allows `get`, `list`
   and `watch` on Pods, and `get` on Pod logs. Bind it to `orion-ci` with a
   RoleBinding named `orion-ci-pod-reader`.

3. Use `kubectl auth can-i` to check whether `orion-ci` may delete Pods in
   Namespace `orion`. Write the command's output into
   `/opt/course/5/can-delete`.
