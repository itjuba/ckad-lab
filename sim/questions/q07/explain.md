# Lesson 7: Debugging a crashing app, and env vars from a ConfigMap

Curriculum: "Debugging in Kubernetes" and "Utilize container logs" (Application
Observability and Maintenance, 15%), plus "Understand ConfigMaps" (Configuration, 25%).

------------------------------------------------------------------------------------------
## 1. A debugging routine that always works

When something is broken, go through the same four steps:

  1. k get pods -n <ns>                 what's wrong?    STATUS, READY, RESTARTS
  2. k describe pod <name> -n <ns>      why?             Events, Last State, exit code
  3. k logs <name> -n <ns>              what did the app say?
  4. k exec <name> -n <ns> -- <cmd>     look inside (env, files, network)

STATUS values and what they usually mean:

  Pending             not scheduled yet (no node fits, see lesson 40)
  ContainerCreating   still starting, or waiting for a volume/ConfigMap/Secret
  ImagePullBackOff    image name or tag is wrong, or the registry is unreachable
  CrashLoopBackOff    the container starts, exits, and gets restarted again and again
  Error               the container exited with a non-zero code
  OOMKilled           it used more memory than its limit (lesson 25)

CrashLoopBackOff almost always means "read the logs": the app usually prints why it quit.

------------------------------------------------------------------------------------------
## 2. Logs

```bash
k logs <pod> -n <ns>                  # output of the container
k logs <pod> -n <ns> --previous       # output of the LAST CRASHED run (-p)
k logs <pod> -n <ns> -c <container>   # pick a container in a multi-container Pod
k logs <pod> -n <ns> --tail=20        # last 20 lines
k logs deploy/<name> -n <ns>          # a Pod of that Deployment, no need for the Pod name
k logs <pod> -n <ns> | grep -i error  # find the interesting line
```

When the container is between restarts, the current log may be empty: use --previous.

------------------------------------------------------------------------------------------
## 3. Fix the Deployment, not the Pod

Pods created by a Deployment are replaced constantly. Editing such a Pod is pointless:
the next Pod comes from the Deployment's template again. Always change the Deployment:

```bash
k edit deploy <name> -n <ns>          # opens the YAML in vim; saving triggers a rollout
k rollout status deploy <name> -n <ns>
```

------------------------------------------------------------------------------------------
## 4. ConfigMaps and environment variables

A ConfigMap stores settings as key/value pairs, outside the image:

```bash
k create configmap app-config -n <ns> --from-literal=queue.url=amqp://q:5672
k describe cm app-config -n <ns>      # shows keys and values
```

Three ways to get a value into a container's environment:

```yaml
    env:
    - name: MODE                      # 1. a fixed value
      value: production
    - name: QUEUE_URL                 # 2. ONE key, under a name YOU choose
      valueFrom:
        configMapKeyRef:
          name: app-config            #    the ConfigMap
          key: queue.url              #    the key inside it
    envFrom:                          # 3. ALL keys; each key name becomes the var name
    - configMapRef:
        name: app-config
```

Imperative shortcut: `kubectl set env` can do option 2 for you, and it turns the key
name into an upper-case variable name (`queue.url` becomes `QUEUE_URL`):

```bash
k set env deploy/<name> -n <ns> --from=configmap/app-config --keys=queue.url
k set env deploy/<name> -n <ns> --list          # show the result
```

Check inside a running Pod: `k exec <pod> -n <ns> -- printenv QUEUE_URL`.

------------------------------------------------------------------------------------------
## 5. How this applies to question 7

  Task 1  Find the Deployment whose Pod keeps restarting (STATUS and RESTARTS columns).
          The file wants the DEPLOYMENT name, not the Pod name (Pod name = deployment
          name + two random parts).
  Task 2  Read its logs (maybe --previous) and copy only the error line into the file.
  Task 3  The error message tells you the exact variable name the app expects. The value
          must come FROM the ConfigMap key, so use option 2 above (by YAML or with
          `k set env --from ... --keys ...`). Then confirm the new Pod stays Running and
          its logs look healthy.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Writing the Pod name instead of the Deployment name
  - Copying the value into the Deployment (`value: amqp://...`) instead of referencing it
  - `envFrom`: the variable would be named after the key (`queue.url`), not QUEUE_URL
  - Editing the crashing Pod instead of the Deployment
  - Saving the whole log instead of the error line

------------------------------------------------------------------------------------------
## 7. Docs (kubernetes.io)

  Search "Debug Running Pods" / "Debug Pods"        the debugging workflow
  Search "Configure a Pod to Use a ConfigMap"       env, valueFrom, envFrom snippets
  Search "kubectl logs"                             all logs flags

See also: ckad explain 15 and 37 (ConfigMaps), ckad explain 30 (logs and exec)

Now try it: ckad q 7
