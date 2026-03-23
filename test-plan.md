# CKAD Lab — Full Test Plan (43 Challenges)

## Exam Info
- **Format:** 15-20 performance-based tasks (hands-on, no multiple choice)
- **Time:** 2 hours
- **Passing:** 66%
- **Kubernetes:** v1.35
- **Key Rule:** CKAD is a speed test, not a knowledge test

## Exam Setup (type at start)
```bash
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```

Pre-configured on exam: `k` alias, bash autocompletion for kubectl

---

## Domain 1: Application Design & Build (20%) — 8 Challenges

| # | Challenge | Time | Key Skills |
|---|-----------|------|-----------|
| 1.1 | Create a basic pod | 2 min | `kubectl run`, `get po -o wide` |
| 1.2 | Pod with labels, port & annotations | 3 min | `--labels`, `--port`, `annotate` |
| 1.3 | Generate & edit YAML | 3 min | `--dry-run=client -o yaml`, vim, `apply -f` |
| 1.4 | Pod with env vars | 2 min | `--env`, verify with `exec` |
| 1.5 | Multi-container pod (sidecar) | 5 min | Edit YAML, shared volume |
| 1.6 | Init container | 5 min | Init + main container, emptyDir |
| 1.7 | Persistent & ephemeral volumes | 5 min | PV, PVC, mount in pod |
| 1.8 | Docker/container basics | 3 min | Image inspection |

### Challenge 1.1 — Create a Basic Pod (2 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** The dev team needs a quick web server for testing.
**Tasks:**
1. Create a pod named `webserver` using image `nginx:alpine`
2. Verify it's Running
3. Get the pod's IP address
4. Delete the pod

**Answer:**
```bash
kubectl run webserver --image=nginx:alpine
kubectl get po
kubectl get po -o wide
kubectl delete po webserver --force --grace-period=0
```

### Challenge 1.2 — Pod with Labels, Port & Annotations (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Create a pod with proper labeling for service discovery.
**Tasks:**
1. Create a pod named `api-server` with image `httpd:alpine`
2. Add labels `app=api` and `tier=backend`
3. Expose container port `80`
4. Add annotation `description=API server pod`
5. Verify labels and annotations

**Answer:**
```bash
kubectl run api-server --image=httpd:alpine --labels='app=api,tier=backend' --port=80
kubectl annotate pod api-server description="API server pod"
kubectl get po api-server --show-labels
kubectl describe po api-server | grep -i annotation
```

### Challenge 1.3 — Generate & Edit YAML (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Create a pod named `db-pod` with image `redis:alpine` and env var `REDIS_PASSWORD=secret123`.
**Tasks:**
1. Generate the pod YAML skeleton and save to `q3.yml`
2. Apply the file
3. Verify the pod is running
4. Verify the env var is set inside the pod

**Answer:**
```bash
kubectl run db-pod --image=redis:alpine --env=REDIS_PASSWORD=secret123 --dry-run=client -o yaml > q3.yml
kubectl apply -f q3.yml
kubectl get po db-pod
kubectl exec db-pod -- env | grep REDIS
```

### Challenge 1.4 — Pod with Multiple Env Vars (2 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Create a pod with multiple environment variables.
**Tasks:**
1. Create pod named `app-pod` with image `busybox` that runs `env` command
2. Set env vars: `APP_NAME=myapp`, `APP_ENV=production`
3. Verify env vars in the output

**Answer:**
```bash
kubectl run app-pod --image=busybox --env=APP_NAME=myapp --env=APP_ENV=production --restart=Never -- env
kubectl logs app-pod | grep APP
```

### Challenge 1.5 — Multi-Container Pod / Sidecar (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Create a pod with a main nginx container and a sidecar that writes logs.
**Tasks:**
1. Generate YAML for pod named `multi-pod` with image `nginx`
2. Add a sidecar container named `logger` with image `busybox` that runs `sh -c 'while true; do echo "$(date) - logging" >> /var/log/app.log; sleep 5; done'`
3. Share a volume named `shared-logs` (emptyDir) mounted at `/var/log` in both containers
4. Apply and verify both containers are running

**Answer:**
```bash
kubectl run multi-pod --image=nginx --dry-run=client -o yaml > q5.yml
# Edit q5.yml to add second container and shared emptyDir volume
kubectl apply -f q5.yml
kubectl get po multi-pod
kubectl exec multi-pod -c logger -- cat /var/log/app.log
```

### Challenge 1.6 — Init Container (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Create a pod where an init container downloads config before the main app starts.
**Tasks:**
1. Create pod named `init-pod` with main container `nginx:alpine`
2. Add init container named `init-setup` with image `busybox` that runs `sh -c 'echo "init done" > /work-dir/init.txt'`
3. Both containers share emptyDir volume at `/work-dir`
4. Verify init completed and main container can read init.txt

**Answer:**
```bash
kubectl run init-pod --image=nginx:alpine --dry-run=client -o yaml > q6.yml
# Edit q6.yml to add initContainers and shared emptyDir volume
kubectl apply -f q6.yml
kubectl exec init-pod -- cat /work-dir/init.txt
```

### Challenge 1.7 — Persistent & Ephemeral Volumes (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Create a PV, PVC, and a pod that uses persistent storage.
**Tasks:**
1. Create a PersistentVolume named `task-pv` with 1Gi, hostPath `/mnt/data`, accessMode `ReadWriteOnce`
2. Create a PersistentVolumeClaim named `task-pvc` requesting 500Mi
3. Create pod named `storage-pod` with image `nginx` mounting the PVC at `/usr/share/nginx/html`
4. Verify the PVC is bound

**Answer:**
```bash
# Create PV YAML and apply
# Create PVC YAML and apply
kubectl get pv,pvc
kubectl run storage-pod --image=nginx --dry-run=client -o yaml > q7.yml
# Edit to add volume and volumeMount for PVC
kubectl apply -f q7.yml
kubectl get pvc
```

### Challenge 1.8 — Docker/Container Basics (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Inspect container images.
**Tasks:**
1. Create a pod named `inspect-pod` with image `nginx:alpine`
2. Get the container ID from pod details
3. Check which node the pod is running on

**Answer:**
```bash
kubectl run inspect-pod --image=nginx:alpine
kubectl get po inspect-pod -o wide
kubectl describe po inspect-pod | grep -i "container id"
```

---

## Domain 2: Application Deployment (20%) — 7 Challenges

| # | Challenge | Time | Key Skills |
|---|-----------|------|-----------|
| 2.1 | Create a deployment | 2 min | `create deployment`, replicas |
| 2.2 | Scale a deployment | 2 min | `kubectl scale` |
| 2.3 | Rolling update | 3 min | `set image`, `rollout status` |
| 2.4 | Rollback | 3 min | `rollout undo`, `rollout history` |
| 2.5 | Canary deployment | 5 min | Two deployments, replica ratio |
| 2.6 | Helm basics | 5 min | `helm install`, `upgrade`, `rollback` |
| 2.7 | Kustomize | 3 min | `kubectl apply -k` |

### Challenge 2.1 — Create a Deployment (2 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Deploy a web application.
**Tasks:**
1. Create a deployment named `web-deploy` with image `nginx:1.21` and 3 replicas
2. Verify all 3 pods are running
3. Check the ReplicaSet created

**Answer:**
```bash
kubectl create deployment web-deploy --image=nginx:1.21 --replicas=3
kubectl get deploy web-deploy
kubectl get po
kubectl get rs
```

### Challenge 2.2 — Scale a Deployment (2 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Traffic increased, scale up the deployment.
**Tasks:**
1. Scale `web-deploy` to 5 replicas
2. Verify 5 pods are running
3. Scale back down to 2 replicas

**Answer:**
```bash
kubectl scale deploy web-deploy --replicas=5
kubectl get po
kubectl scale deploy web-deploy --replicas=2
kubectl get po
```

### Challenge 2.3 — Rolling Update (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Update the web app to a new version.
**Tasks:**
1. Update `web-deploy` image from `nginx:1.21` to `nginx:1.25`
2. Watch the rollout status
3. Verify the new image is running

**Answer:**
```bash
kubectl set image deploy/web-deploy nginx=nginx:1.25
kubectl rollout status deploy/web-deploy
kubectl describe deploy web-deploy | grep Image
```

### Challenge 2.4 — Rollback (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** The new version has a bug. Roll back.
**Tasks:**
1. Check rollout history of `web-deploy`
2. Roll back to the previous version
3. Verify the old image is restored

**Answer:**
```bash
kubectl rollout history deploy/web-deploy
kubectl rollout undo deploy/web-deploy
kubectl describe deploy web-deploy | grep Image
```

### Challenge 2.5 — Canary Deployment (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Deploy a canary version alongside stable.
**Tasks:**
1. Create deployment `stable-app` with image `nginx:1.21`, 3 replicas, label `app=myapp`
2. Create deployment `canary-app` with image `nginx:1.25`, 1 replica, label `app=myapp`
3. Create a service `myapp-svc` that selects `app=myapp` on port 80
4. Verify endpoints include pods from both deployments (75/25 split)

**Answer:**
```bash
kubectl create deploy stable-app --image=nginx:1.21 --replicas=3
kubectl label deploy stable-app app=myapp --overwrite
kubectl create deploy canary-app --image=nginx:1.25 --replicas=1
kubectl label deploy canary-app app=myapp --overwrite
kubectl expose deploy stable-app --name=myapp-svc --port=80 --selector=app=myapp
kubectl get ep myapp-svc
```

### Challenge 2.6 — Helm Basics (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Deploy an app using Helm.
**Tasks:**
1. Add the bitnami repo
2. Search for nginx chart
3. Install nginx chart as release `my-nginx`
4. List helm releases
5. Uninstall the release

**Answer:**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search repo nginx
helm install my-nginx bitnami/nginx
helm list
helm uninstall my-nginx
```

### Challenge 2.7 — Kustomize (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Use kustomize to deploy with customizations.
**Tasks:**
1. Create a kustomization.yaml that references a deployment
2. Apply using `kubectl apply -k`
3. Verify resources created

**Answer:**
```bash
# Create base deployment YAML
# Create kustomization.yaml referencing it
kubectl apply -k ./
kubectl get all
```

---

## Domain 3: Observability & Maintenance (15%) — 5 Challenges

| # | Challenge | Time | Key Skills |
|---|-----------|------|-----------|
| 3.1 | View & follow logs | 2 min | `logs`, `-f`, `--previous`, `-c` |
| 3.2 | Liveness probe | 4 min | exec, httpGet |
| 3.3 | Readiness probe | 4 min | httpGet, tcpSocket |
| 3.4 | Fix a broken pod | 5 min | `describe`, `logs`, fix & verify |
| 3.5 | Resource monitoring | 3 min | `kubectl top` |

### Challenge 3.1 — View & Follow Logs (2 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Debug a running application using logs.
**Tasks:**
1. Create pod named `logger` with image `busybox` running `sh -c 'while true; do echo "$(date) - heartbeat"; sleep 2; done'`
2. View the last 10 lines of logs
3. Follow logs in real-time (then Ctrl+C)
4. View logs from a previous crashed container (if applicable)

**Answer:**
```bash
kubectl run logger --image=busybox --restart=Never -- sh -c 'while true; do echo "$(date) - heartbeat"; sleep 2; done'
kubectl logs logger --tail=10
kubectl logs logger -f
kubectl logs logger --previous
```

### Challenge 3.2 — Liveness Probe (4 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Add a liveness probe to detect stuck containers.
**Tasks:**
1. Generate YAML for pod named `liveness-pod` with image `nginx`
2. Add liveness probe: httpGet on port 80 path `/`, initialDelaySeconds 5, periodSeconds 10
3. Apply and verify probe is configured
4. Check events for probe status

**Answer:**
```bash
kubectl run liveness-pod --image=nginx --dry-run=client -o yaml > q32.yml
# Edit to add livenessProbe
kubectl apply -f q32.yml
kubectl describe po liveness-pod | grep -i liveness
```

### Challenge 3.3 — Readiness Probe (4 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Add a readiness probe so traffic only goes to ready pods.
**Tasks:**
1. Generate YAML for pod named `readiness-pod` with image `nginx`
2. Add readiness probe: httpGet on port 80 path `/`, initialDelaySeconds 3, periodSeconds 5
3. Apply and verify
4. Check if pod shows READY 1/1

**Answer:**
```bash
kubectl run readiness-pod --image=nginx --dry-run=client -o yaml > q33.yml
# Edit to add readinessProbe
kubectl apply -f q33.yml
kubectl get po readiness-pod
kubectl describe po readiness-pod | grep -i readiness
```

### Challenge 3.4 — Fix a Broken Pod (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** A pod is failing. Diagnose and fix it.
**Tasks:**
1. Create pod named `broken-pod` with image `nginx:nonexistent`
2. Identify why it's failing
3. Fix the image to `nginx:alpine`
4. Verify it's now running

**Answer:**
```bash
kubectl run broken-pod --image=nginx:nonexistent
kubectl get po broken-pod
kubectl describe po broken-pod | grep -i events -A 10
kubectl set image pod/broken-pod broken-pod=nginx:alpine
kubectl get po broken-pod
```

### Challenge 3.5 — Resource Monitoring (3 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Check resource usage across the cluster.
**Tasks:**
1. View node resource usage
2. View pod resource usage across all namespaces
3. Sort pods by CPU usage

**Answer:**
```bash
kubectl top nodes
kubectl top pods -A
kubectl top pods -A --sort-by=cpu
```

---

## Domain 4: Config & Security (25%) — 10 Challenges

| # | Challenge | Time | Key Skills |
|---|-----------|------|-----------|
| 4.1 | Create ConfigMap (imperative) | 2 min | `--from-literal`, `--from-file` |
| 4.2 | ConfigMap as env var | 4 min | `envFrom`, `configMapKeyRef` |
| 4.3 | ConfigMap as volume | 4 min | `volumeMounts`, `volumes` |
| 4.4 | Create & use Secrets | 4 min | `create secret generic`, mount |
| 4.5 | ServiceAccounts | 3 min | `create sa`, assign to pod |
| 4.6 | SecurityContext (pod level) | 4 min | `runAsUser`, `fsGroup` |
| 4.7 | SecurityContext (container level) | 4 min | `capabilities`, override |
| 4.8 | Resource requests & limits | 3 min | `resources.requests/limits` |
| 4.9 | ResourceQuotas & LimitRanges | 5 min | Namespace-level controls |
| 4.10 | CRDs | 5 min | Create CRD, custom object |

### Challenge 4.1 — Create ConfigMap (2 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create ConfigMap named `app-config` with `APP_COLOR=blue` and `APP_MODE=prod`
2. Create ConfigMap named `file-config` from a file
3. View the ConfigMap data

**Answer:**
```bash
kubectl create configmap app-config --from-literal=APP_COLOR=blue --from-literal=APP_MODE=prod
echo "key1=val1" > config.txt
kubectl create configmap file-config --from-file=config.txt
kubectl get cm app-config -o yaml
```

### Challenge 4.2 — ConfigMap as Env Var (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create ConfigMap `db-config` with `DB_HOST=mysql` and `DB_PORT=3306`
2. Create pod `app-pod` with image `busybox` that uses ALL ConfigMap keys as env vars (envFrom)
3. Verify env vars inside the pod

**Answer:**
```bash
kubectl create configmap db-config --from-literal=DB_HOST=mysql --from-literal=DB_PORT=3306
kubectl run app-pod --image=busybox --restart=Never --dry-run=client -o yaml > q42.yml
# Edit to add envFrom with configMapRef
kubectl apply -f q42.yml
kubectl exec app-pod -- env | grep DB
```

### Challenge 4.3 — ConfigMap as Volume (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create ConfigMap `nginx-config` with key `nginx.conf` containing custom config
2. Mount it as volume in pod `nginx-custom` at `/etc/nginx/conf.d`
3. Verify the file exists inside the pod

**Answer:**
```bash
kubectl create configmap nginx-config --from-literal=nginx.conf="server { listen 8080; }"
kubectl run nginx-custom --image=nginx --dry-run=client -o yaml > q43.yml
# Edit to add volume and volumeMount for configMap
kubectl apply -f q43.yml
kubectl exec nginx-custom -- ls /etc/nginx/conf.d
```

### Challenge 4.4 — Create & Use Secrets (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create secret named `db-secret` with `username=admin` and `password=s3cret`
2. Create pod `secret-pod` with image `busybox` using secret as env vars
3. Verify by running `env` inside the pod
4. Decode the secret from kubectl output

**Answer:**
```bash
kubectl create secret generic db-secret --from-literal=username=admin --from-literal=password=s3cret
kubectl run secret-pod --image=busybox --restart=Never --dry-run=client -o yaml > q44.yml
# Edit to add envFrom with secretRef
kubectl apply -f q44.yml
kubectl exec secret-pod -- env | grep -E "username|password"
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d
```

### Challenge 4.5 — ServiceAccounts (3 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create ServiceAccount named `app-sa`
2. Create pod `sa-pod` with image `nginx` using `app-sa`
3. Verify the SA is assigned

**Answer:**
```bash
kubectl create sa app-sa
kubectl run sa-pod --image=nginx --dry-run=client -o yaml > q45.yml
# Edit to add serviceAccountName: app-sa
kubectl apply -f q45.yml
kubectl describe po sa-pod | grep -i "service account"
```

### Challenge 4.6 — SecurityContext Pod Level (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create pod `secure-pod` with image `busybox` running `sleep 3600`
2. Set pod-level securityContext: `runAsUser: 1000`, `fsGroup: 2000`
3. Verify by running `id` inside the pod

**Answer:**
```bash
kubectl run secure-pod --image=busybox --dry-run=client -o yaml -- sleep 3600 > q46.yml
# Edit to add securityContext at pod level
kubectl apply -f q46.yml
kubectl exec secure-pod -- id
```

### Challenge 4.7 — SecurityContext Container Level (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create pod `cap-pod` with image `busybox` running `sleep 3600`
2. At container level: add capabilities `NET_ADMIN` and `SYS_TIME`
3. Set `allowPrivilegeEscalation: false`
4. Verify capabilities

**Answer:**
```bash
kubectl run cap-pod --image=busybox --dry-run=client -o yaml -- sleep 3600 > q47.yml
# Edit to add container-level securityContext with capabilities
kubectl apply -f q47.yml
kubectl exec cap-pod -- cat /proc/1/status | grep Cap
```

### Challenge 4.8 — Resource Requests & Limits (3 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create pod `resource-pod` with image `nginx`
2. Set requests: cpu `100m`, memory `128Mi`
3. Set limits: cpu `200m`, memory `256Mi`
4. Verify resources are set

**Answer:**
```bash
kubectl run resource-pod --image=nginx --dry-run=client -o yaml > q48.yml
# Edit to add resources.requests and resources.limits
kubectl apply -f q48.yml
kubectl describe po resource-pod | grep -A 5 "Limits\|Requests"
```

### Challenge 4.9 — ResourceQuotas & LimitRanges (5 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create namespace `restricted`
2. Create ResourceQuota in `restricted`: max 2 pods, 1 CPU, 1Gi memory
3. Create LimitRange: default container limits cpu `200m`, memory `256Mi`
4. Try to exceed the quota

**Answer:**
```bash
kubectl create ns restricted
kubectl create quota my-quota --hard=pods=2,cpu=1,memory=1Gi -n restricted
# Create LimitRange YAML and apply
kubectl apply -f limitrange.yml -n restricted
kubectl get quota,limitrange -n restricted
```

### Challenge 4.10 — CRDs (5 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create a CRD named `widgets.example.com` with kind `Widget`
2. Create a custom Widget object
3. List widgets using short name

**Answer:**
```bash
# Create CRD YAML with openAPIV3Schema
kubectl apply -f crd.yml
# Create Widget instance YAML
kubectl apply -f widget.yml
kubectl get widgets
```

---

## Domain 5: Services & Networking (20%) — 8 Challenges

| # | Challenge | Time | Key Skills |
|---|-----------|------|-----------|
| 5.1 | ClusterIP service | 3 min | `kubectl expose` |
| 5.2 | NodePort service | 3 min | `--type=NodePort` |
| 5.3 | Service DNS discovery | 4 min | `nslookup` from busybox |
| 5.4 | Endpoints verification | 3 min | `kubectl get ep` |
| 5.5 | Ingress | 5 min | Create ingress rules |
| 5.6 | Debug broken Ingress | 5 min | Fix 404, check service |
| 5.7 | NetworkPolicy (allow) | 5 min | Ingress rules by label |
| 5.8 | NetworkPolicy (deny all) | 4 min | Default deny policy |

### Challenge 5.1 — ClusterIP Service (3 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create deployment `web` with image `nginx` and 2 replicas
2. Expose it as ClusterIP service named `web-svc` on port 80
3. Verify endpoints
4. Test connectivity from a temp busybox pod

**Answer:**
```bash
kubectl create deploy web --image=nginx --replicas=2
kubectl expose deploy web --name=web-svc --port=80
kubectl get ep web-svc
kubectl run tmp --image=busybox --restart=Never --rm -it -- wget -qO- web-svc
```

### Challenge 5.2 — NodePort Service (3 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Expose `web` deployment as NodePort service named `web-np` on port 80
2. Find the assigned NodePort
3. Verify access

**Answer:**
```bash
kubectl expose deploy web --name=web-np --port=80 --type=NodePort
kubectl get svc web-np
```

### Challenge 5.3 — Service DNS Discovery (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create namespace `apps`
2. Create pod `dns-test` in `apps` namespace with image `nginx`
3. Expose it as service `dns-svc` in `apps`
4. From default namespace, resolve the service DNS using busybox

**Answer:**
```bash
kubectl create ns apps
kubectl run dns-test --image=nginx -n apps
kubectl expose pod dns-test --name=dns-svc --port=80 -n apps
kubectl run tmp --image=busybox --restart=Never --rm -it -- nslookup dns-svc.apps.svc.cluster.local
```

### Challenge 5.4 — Endpoints Verification (3 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create deployment `ep-test` with image `nginx` and 3 replicas
2. Expose as service `ep-svc` on port 80
3. Verify endpoints match pod IPs
4. Scale to 1 and check endpoints again

**Answer:**
```bash
kubectl create deploy ep-test --image=nginx --replicas=3
kubectl expose deploy ep-test --name=ep-svc --port=80
kubectl get ep ep-svc
kubectl get po -o wide
kubectl scale deploy ep-test --replicas=1
kubectl get ep ep-svc
```

### Challenge 5.5 — Ingress (5 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create deployment `web-app` with image `nginx`
2. Expose as ClusterIP service on port 80
3. Create ingress `web-ingress` that routes `myapp.local/` to `web-app` service

**Answer:**
```bash
kubectl create deploy web-app --image=nginx
kubectl expose deploy web-app --port=80
kubectl create ingress web-ingress --rule="myapp.local/=web-app:80"
kubectl get ingress
kubectl describe ingress web-ingress
```

### Challenge 5.6 — Debug Broken Ingress (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** An ingress returns 404. Find and fix the issue.
**Tasks:**
1. Check ingress rules
2. Check if service exists and matches
3. Check endpoints
4. Fix the issue

**Answer:**
```bash
kubectl describe ingress web-ingress
kubectl get svc
kubectl get ep
# Fix: ensure service name in ingress matches actual service
# Fix: ensure service port matches
```

### Challenge 5.7 — NetworkPolicy Allow (5 min)
**Context:** `kubectl config use-context minikube`
**Scenario:** Only allow backend pods to access the database.
**Tasks:**
1. Create namespace `netpol`
2. Create pod `db` with label `role=db` in `netpol`
3. Create pod `backend` with label `role=backend` in `netpol`
4. Create pod `frontend` with label `role=frontend` in `netpol`
5. Create NetworkPolicy allowing ingress to `db` only from `role=backend` on port 3306

**Answer:**
```bash
kubectl create ns netpol
kubectl run db --image=nginx -n netpol --labels=role=db --port=3306
kubectl run backend --image=busybox -n netpol --labels=role=backend --restart=Never -- sleep 3600
kubectl run frontend --image=busybox -n netpol --labels=role=frontend --restart=Never -- sleep 3600
# Create NetworkPolicy YAML and apply
kubectl apply -f netpol.yml -n netpol
```

### Challenge 5.8 — NetworkPolicy Deny All (4 min)
**Context:** `kubectl config use-context minikube`
**Tasks:**
1. Create a default deny-all ingress NetworkPolicy in namespace `secure`
2. Verify no pods can communicate

**Answer:**
```bash
kubectl create ns secure
# Create deny-all NetworkPolicy YAML
kubectl apply -f deny-all.yml -n secure
kubectl get netpol -n secure
```

---

## Speed Drills (Bonus) — 5 Challenges

### Drill S.1 — Context Switch + Create (30 sec)
**Tasks:**
1. Switch to minikube context
2. Set namespace to `default`
3. Create pod `speed-pod` with image `nginx:alpine`

**Answer:**
```bash
kubectl config use-context minikube
kubectl config set-context --current --namespace=default
kubectl run speed-pod --image=nginx:alpine
```

### Drill S.2 — Generate, Edit, Apply (2 min)
**Tasks:**
1. Generate deployment YAML with 3 replicas
2. Add resource limits (cpu 200m, memory 256Mi)
3. Apply and verify

### Drill S.3 — Debug Broken Pod (3 min)
**Tasks:**
1. A pod with wrong image is created for you
2. Find the error
3. Fix and verify

### Drill S.4 — Full Multi-Step Scenario (7 min)
**Tasks:**
1. Create namespace `exam`
2. Create ConfigMap with DB connection info
3. Create Secret with credentials
4. Create Deployment using ConfigMap and Secret
5. Expose with ClusterIP service
6. Verify connectivity

### Drill S.5 — Rapid Fire (2 min)
**Tasks:** Execute these 5 commands as fast as possible:
1. Create namespace `quick`
2. Create pod in that namespace
3. Label the pod
4. Expose the pod
5. Delete everything

---

## Key Commands Reference

### Imperative
```bash
kubectl run <pod> --image=<img>                    # Create pod
kubectl create deploy <name> --image=<img>         # Create deployment
kubectl expose deploy <name> --port=80             # Create service
kubectl create cm <name> --from-literal=k=v        # Create configmap
kubectl create secret generic <name> --from-literal=k=v  # Create secret
kubectl create ns <name>                           # Create namespace
kubectl create sa <name>                           # Create service account
kubectl create job <name> --image=<img>            # Create job
kubectl create cronjob <name> --image=<img> --schedule="* * * * *"  # Create cronjob
kubectl create ingress <name> --rule="host/path=svc:port"  # Create ingress
```

### YAML Generation
```bash
kubectl <command> --dry-run=client -o yaml > file.yml
```

### Debugging
```bash
kubectl get po                                     # List pods
kubectl describe po <pod>                          # Detailed info + events
kubectl logs <pod>                                 # Container logs
kubectl logs <pod> -c <container>                  # Specific container logs
kubectl logs <pod> --previous                      # Previous crash logs
kubectl exec -it <pod> -- /bin/sh                  # Shell into pod
kubectl get events --sort-by='.lastTimestamp'       # Recent events
```

### Deployments
```bash
kubectl set image deploy/<name> <container>=<img>  # Update image
kubectl rollout status deploy/<name>               # Watch rollout
kubectl rollout history deploy/<name>              # View history
kubectl rollout undo deploy/<name>                 # Rollback
kubectl scale deploy/<name> --replicas=N           # Scale
```

### Useful Flags
```bash
-o wide                    # Show extra columns (IP, node)
-o yaml                    # Output as YAML
-o jsonpath='{.spec...}'   # Extract specific field
--show-labels              # Show labels column
-l app=nginx               # Filter by label
-A                         # All namespaces
--sort-by='.metadata.name' # Sort output
```

### Short Names
```
po=pod  svc=service  deploy=deployment  ns=namespace  cm=configmap
sa=serviceaccount  pv=persistentvolume  pvc=persistentvolumeclaim
ing=ingress  netpol=networkpolicy  ds=daemonset  rs=replicaset
sts=statefulset  hpa=horizontalpodautoscaler  cj=cronjob  ep=endpoints
```
