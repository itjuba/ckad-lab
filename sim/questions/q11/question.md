# Build, push and run a container image

Namespace: `polaris`

Team Polaris has an audit agent in `/opt/course/11/image/` (a `Dockerfile` and
`run.sh`). Docker is available in this terminal, and the cluster pulls images
from the registry at `localhost:5000`.

1. Change the `Dockerfile` so that the environment variable `ROLE` defaults to
   `auditor`.

2. Build the image with the build argument `BUILD=v1`. Tag it as both
   `localhost:5000/nimbus-auditor:v1` and `localhost:5000/nimbus-auditor:latest`,
   and push both tags to the registry.

3. Run a Pod named `auditor` in Namespace `polaris` from the image
   `localhost:5000/nimbus-auditor:v1`.

4. Write the Pod's logs into `/opt/course/11/logs`.

5. Export the image `localhost:5000/nimbus-auditor:v1` as a tar archive to
   `/opt/course/11/nimbus-auditor-v1.tar`.
