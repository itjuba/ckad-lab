# Lock down traffic with NetworkPolicies

Namespace: `altair`

The `altair` Namespace runs four Deployments: `frontend`, `api`, `db` and
`admin`. Every Pod carries the label `app=<deployment name>`, and the Services
`api` and `db` listen on port 80. Right now every Pod can talk to every other Pod.

Create these NetworkPolicies in Namespace `altair`:

1. `default-deny-ingress`: blocks all incoming traffic to every Pod in the Namespace.

2. `allow-api`: Pods with `app=api` accept incoming traffic only from Pods with
   `app=frontend`, on TCP port 80.

3. `allow-db`: Pods with `app=db` accept incoming traffic only from Pods with
   `app=api`, on TCP port 80.

4. `api-egress`: Pods with `app=api` may only send traffic to Pods with `app=db`
   on TCP port 80. DNS lookups (UDP and TCP port 53) must keep working.

Test the result with `kubectl exec` and `wget`.
