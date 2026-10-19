# Service and cross-namespace DNS

Namespace: `phoenix` (and a temporary Pod in `default`)

Team Phoenix is publishing an internal API. Other teams will reach it through
cluster DNS from their own namespaces.

1. Create a Pod named `phoenix-api` in Namespace `phoenix`, image
   `nginx:1.29-alpine`, label `app=phoenix-api`, container port `80` named `http`.

2. Create a ClusterIP Service `phoenix-api-svc` in `phoenix` that listens on
   port `3333` and forwards to the Pod's **named** port `http`.

3. From a temporary Pod in Namespace `default`, request the Service by its
   fully qualified DNS name on port 3333. Save the response body to
   `/opt/course/10/response.html`.

4. Write the nginx access-log line for that request into
   `/opt/course/10/access.log`.

5. Make sure the temporary Pod is gone afterwards.
