# A dedicated ServiceAccount

Namespace: `reticulum`

The Deployment `reticulum-app` runs with the namespace's `default` ServiceAccount. The
security team wants it to have its own identity, and it never talks to the Kubernetes API.

1. Create a ServiceAccount `reticulum-runner` in `reticulum`.

2. Make the Pods of Deployment `reticulum-app` run as `reticulum-runner`.

3. Turn off automatic mounting of the API token for those Pods
   (`automountServiceAccountToken: false` in the Pod template).

4. All replicas must be updated and available afterwards.

5. Write the name of the ServiceAccount that a running `reticulum-app` Pod uses into
   `/opt/course/41/sa-name`.
