# Service with two named ports

Namespace: `pictor`

The Deployment `pictor-app` runs Pods with two containers: `web` serves the website on
the container port named `http` (80), and `metrics` serves metrics on the container port
named `metrics` (9100).

1. Create a ClusterIP Service `pictor-app` in `pictor` for the Pods of the Deployment,
   with two ports:
   - name `http`, port `80`, targetPort the named container port `http`
   - name `metrics`, port `9100`, targetPort the named container port `metrics`

2. Create a NodePort Service `pictor-app-ext` that exposes **only** the website (port 80,
   targetPort `http`) on nodePort `30781`.

3. Save the output of `curl -s http://k3d-ckad-server-0:30781` to
   `/opt/course/39/nodeport.html`.

4. From a temporary Pod in `pictor`, request `http://pictor-app:9100` and save the response
   to `/opt/course/39/metrics.txt`. Delete the temporary Pod afterwards.
