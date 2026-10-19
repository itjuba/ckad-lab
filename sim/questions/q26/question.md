# Blue/green switch

Namespace: `tucana`

The checkout service of team Tucana runs as the "blue" version behind the Service
`checkout`. Release the "green" version with a blue/green switch: all traffic moves at
once, and blue stays around for a quick rollback.

1. Create a Deployment `checkout-green` in `tucana`:
   - 3 replicas, image `traefik/whoami:v1.11`, container arg `--name=green`
   - Pod labels `app=checkout` and `version=green`

2. Only once all green Pods are ready, switch the Service `checkout` so it sends
   **all** traffic to green and none to blue.

3. From a temporary Pod in `tucana`, request `http://checkout` and save the response to
   `/opt/course/26/after-switch`. Delete the temporary Pod afterwards.

4. Scale `checkout-blue` down to 0 replicas. Don't delete it.
