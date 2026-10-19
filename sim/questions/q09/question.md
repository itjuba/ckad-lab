# Pod to Deployment with a hardened securityContext

Namespace: `aquila`

Team Aquila runs a reporting Pod by hand. The manifest is at
`/opt/course/9/reporter-pod.yaml`, and the Pod `aquila-reporter` is running.
The security team wants it highly available and locked down.

1. Convert the Pod into a Deployment named `aquila-reporter` with **3** replicas.
   Keep the same container (name, image, command). Save the Deployment manifest
   to `/opt/course/9/reporter-deploy.yaml`.

2. Harden the Deployment's Pods:
   - Pod level: `runAsUser: 1000`, `runAsGroup: 3000`, `fsGroup: 2000`
   - container level: privilege escalation not allowed, read-only root
     filesystem, all Linux capabilities dropped

3. The app writes to `/tmp/report.log`. Make sure it keeps working with the
   read-only root filesystem by mounting an `emptyDir` volume at `/tmp`.

4. Delete the original Pod `aquila-reporter`.
