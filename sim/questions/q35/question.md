# Init container prepares web content

Namespace: `lacerta`

Team Lacerta wants nginx to serve a page that is generated when the Pod starts.

1. Create a Pod `lacerta-web` in Namespace `lacerta` with an emptyDir volume named `content`.

2. An init container `fetch` (image `busybox:1.37`) mounts `content` at `/work` and writes
   the line `<h1>Lacerta</h1>` into `/work/index.html`.

3. The main container `web` (image `nginx:1.29-alpine`) mounts `content` at
   `/usr/share/nginx/html`, so nginx serves that file.

4. From a temporary Pod in Namespace `lacerta`, request the IP address of `lacerta-web` on
   port 80 and save the response to `/opt/course/35/index.html`. Delete the temporary Pod
   afterwards.
