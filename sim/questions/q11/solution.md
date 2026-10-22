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

The build happens on the build host, which shares `/opt/course`:

```bash
ssh ckad-build
cd /opt/course/11/image
# one build, two tags
podman build --build-arg BUILD=v1 -t localhost:5000/nimbus-auditor:v1 -t localhost:5000/nimbus-auditor:latest .
podman push localhost:5000/nimbus-auditor:v1
podman push localhost:5000/nimbus-auditor:latest
podman image ls localhost:5000/nimbus-auditor

podman save -o /opt/course/11/nimbus-auditor-v1.tar localhost:5000/nimbus-auditor:v1
tar -tf /opt/course/11/nimbus-auditor-v1.tar | head -3   # manifest.json, layers
exit                                                       # back to the exam terminal
```

Then, from the terminal (the only place with `kubectl`):

```bash
k run auditor -n polaris --image=localhost:5000/nimbus-auditor:v1
k get pod auditor -n polaris
k logs auditor -n polaris > /opt/course/11/logs
cat /opt/course/11/logs                # nimbus auditor role=auditor build=v1
```

Remember:
- `ARG` values exist only at build time. To see one at runtime, copy it into an `ENV`, as this Dockerfile does with `ENV BUILD=$BUILD`.
- You can repeat `-t` to give one build several tags, but each tag still needs its own `podman push`. `docker build` / `docker push` take the same flags, if a task offers docker instead.
- `podman save -o file.tar <image>` exports an image to a file (`podman load -i file.tar` imports it again). It writes where you run it: on the build host, which is why the task says to export there.
- The shell prompt tells you where you are. Type `exit` when a task on another host is done; `kubectl` on the build host says "command not found".
