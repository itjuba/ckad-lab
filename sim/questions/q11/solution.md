# Solution 11

```bash
cd /opt/course/11/image
vim Dockerfile
```

```dockerfile
FROM busybox:1.37
ARG BUILD=dev
ENV BUILD=$BUILD ROLE=auditor
COPY run.sh /run.sh
CMD ["sh", "/run.sh"]
```

(`ROLE=unset` changed to `ROLE=auditor`. Dockerfiles have no end-of-line
comments: a `#` after an instruction becomes part of its value.)

```bash
# one build, two tags
docker build --build-arg BUILD=v1 -t localhost:5000/nimbus-auditor:v1 -t localhost:5000/nimbus-auditor:latest .
docker push localhost:5000/nimbus-auditor:v1
docker push localhost:5000/nimbus-auditor:latest
docker image ls localhost:5000/nimbus-auditor

k run auditor -n polaris --image=localhost:5000/nimbus-auditor:v1
k get pod auditor -n polaris
k logs auditor -n polaris > /opt/course/11/logs
cat /opt/course/11/logs                # nimbus auditor role=auditor build=v1

docker save localhost:5000/nimbus-auditor:v1 -o /opt/course/11/nimbus-auditor-v1.tar
tar -tf /opt/course/11/nimbus-auditor-v1.tar | head -3   # manifest.json / index.json, layers
```

Remember:
- `ARG` values exist only at build time. To see one at runtime, copy it into an `ENV`, as this Dockerfile does with `ENV BUILD=$BUILD`.
- You can repeat `-t` to give one build several tags, but each tag still needs its own `docker push`. The exam may ask you to do the same with `podman build` and `podman push`, which take the same flags.
- `docker save -o file.tar <image>` (or `podman save -o ...`) exports an image to a file. `docker load -i file.tar` imports it again.
