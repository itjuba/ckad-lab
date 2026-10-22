# Build, push and run a container image

Namespace: `polaris`

Team Polaris has an audit agent in `/opt/course/11/image/` (a `Dockerfile` and
`run.sh`). Images are built on the build host `ckad-build`, which you reach with
`ssh ckad-build`; it has `podman` and sees the same `/opt/course` directory. The
cluster pulls images from the registry `localhost:5000`, which is reachable
under that name from the build host too. `kubectl` only exists in this terminal,
so come back with `exit` for the cluster tasks.

1. Change the `Dockerfile` so that the environment variable `ROLE` defaults to
   `auditor`.

2. On `ckad-build`, build the image with the build argument `BUILD=v1`. Tag it
   as both `localhost:5000/nimbus-auditor:v1` and
   `localhost:5000/nimbus-auditor:latest`, and push both tags to the registry.

3. Run a Pod named `auditor` in Namespace `polaris` from the image
   `localhost:5000/nimbus-auditor:v1`.

4. Write the Pod's logs into `/opt/course/11/logs`.

5. On `ckad-build`, export the image `localhost:5000/nimbus-auditor:v1` as a tar
   archive to `/opt/course/11/nimbus-auditor-v1.tar`.
