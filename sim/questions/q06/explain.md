# Lesson 6: Liveness, readiness and startup probes

Curriculum: "Implement probes and health checks"
(Application Observability and Maintenance, 15%).

------------------------------------------------------------------------------------------
## 1. The problem probes solve

Kubernetes knows whether a container's PROCESS is running. It doesn't know whether the
app inside actually works. A web server can be running but stuck, or still loading for 30
seconds before it can answer. Probes let Kubernetes check the app itself.

------------------------------------------------------------------------------------------
## 2. Three kinds of probe

  readinessProbe   "Can it take traffic right now?"
                   Failing -> Pod is NOT Ready (READY 0/1) and removed from Service
                   endpoints. The container is NOT restarted.

  livenessProbe    "Is it still alive?"
                   Failing -> the container is RESTARTED (RESTARTS goes up).

  startupProbe     "Has it finished starting?"
                   The other two probes wait until this one succeeds once. For slow apps.

Rule of thumb: readiness protects users from a Pod that isn't ready; liveness heals a
Pod that is stuck.

------------------------------------------------------------------------------------------
## 3. How a probe checks

  httpGet     HTTP request; any status 200-399 counts as success
  tcpSocket   success if a TCP connection to the port opens
  exec        runs a command in the container; exit code 0 = success
  grpc        gRPC health check

Timing fields (same for all probe types):

  initialDelaySeconds   wait this long after the container starts (default 0)
  periodSeconds         check every N seconds (default 10)
  timeoutSeconds        a check taking longer counts as failed (default 1)
  failureThreshold      this many failures in a row = probe failed (default 3)
  successThreshold      successes needed to count as OK again (default 1)

------------------------------------------------------------------------------------------
## 4. Where probes go in the YAML

Probes belong to a CONTAINER, at the same level as `image` and `ports`:

```yaml
spec:
  containers:
  - name: web
    image: nginx:1.29-alpine
    ports:
    - containerPort: 80
      name: http
    readinessProbe:
      httpGet:
        path: /healthz        # URL path to request
        port: 80              # a number, or the port name: http
      initialDelaySeconds: 3
      periodSeconds: 5
    livenessProbe:
      tcpSocket:
        port: 80
      periodSeconds: 15
      failureThreshold: 3
    startupProbe:
      exec:
        command: ["cat", "/tmp/started"]
      failureThreshold: 30    # 30 x 10s = up to 5 minutes to start
```

There's no kubectl flag for probes: generate the Pod or Deployment with `$do` and add
the probe block from the docs, or check field names with:

```bash
k explain pod.spec.containers.livenessProbe
k explain pod.spec.containers.livenessProbe.httpGet
```

------------------------------------------------------------------------------------------
## 5. Watching and debugging probes

```bash
k get pod web -w                      # READY 0/1 -> 1/1 when readiness passes
k get pods                            # RESTARTS climbing = liveness keeps failing
k describe pod <pod-name>             # Events: "Readiness probe failed: ..." with reason
k describe deploy <name>              # shows each probe on one line (Liveness/Readiness)
k get events -n <ns>                  # all recent events in the namespace
```

kubectl v1.37 only shows Events when `describe` targets ONE object by name. With `-l` or
several Pods they're hidden: use the Pod name, `--show-events=true`, or `k get events`.

The classic broken probe: the probe checks a port (or path) the app doesn't use. Compare
the probe's port with the container's `containerPort`.

------------------------------------------------------------------------------------------
## 6. How this applies to question 6

  Part 1  Generate a Pod with `$do`, then add two probe blocks under the container. Map
          each sentence of the task to a field: "HTTP GET to path / on port 80" ->
          httpGet; "TCP connection" -> tcpSocket; "starting after" -> initialDelaySeconds;
          "repeating every" -> periodSeconds; "failing after 3 attempts" ->
          failureThreshold. Then wait for READY 1/1.
  Part 2  The Pods restart and never become Ready: both probes are failing. Find out
          WHAT they check and compare it with what the container serves. Fix the
          Deployment (not the Pods: the Deployment replaces them), keep both probes.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Putting probes under `spec` (Pod level) instead of under the container
  - readiness and liveness swapped
  - Editing a Pod of a Deployment: the change is lost when the Pod is replaced
  - Deleting a broken probe to "fix" it: the task wants it fixed, not removed
  - Port number in the probe not matching the port the app listens on

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Configure Liveness, Readiness and Startup Probes"   copy-ready probe snippets
  Search "Pod Lifecycle"                                      container probes explained

See also: ckad explain 7 (debugging a crashing app), ckad explain 25 (restarting Pods)

Now try it: ckad q 6
