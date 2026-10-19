# Ingress with a broken Service

Namespace: `antares`

Team Antares runs two backends in Namespace `antares`: the Deployments
`antares-shop` and `antares-api`, each with a Service of the same name. Requests
to the api backend fail.

1. Fix Service `antares-api` so it reaches the api Pods. Don't change the
   Deployment.

2. Create an Ingress named `antares-ingress` in Namespace `antares`:
   - IngressClass `traefik`
   - host `shop.nimbus.local`
   - path `/shop` (type Prefix) goes to Service `antares-shop` on its Service port
   - path `/api` (type Prefix) goes to Service `antares-api` on its Service port

3. Test the Ingress from the terminal and save the output of this command to
   `/opt/course/18/api-response`:

   `curl -s -H 'Host: shop.nimbus.local' http://k3d-ckad-server-0/api`
