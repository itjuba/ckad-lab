# Lesson 11: Building, pushing, exporting and running container images

Curriculum: "Define, build and modify container images"
(Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. What an image is

An image is a packaged filesystem plus metadata (which command to run, environment
variables, ...). Containers are started from images. Kubernetes doesn't build images; you
build them with podman (or docker), push them to a registry, and Pods pull them from there.

In the exam, as in this lab, you build on a separate host: `ssh <host>`, work there, then
`exit` back to the terminal that has `kubectl`. The prompt shows which host you're on.

Image names:

  localhost:5000/nimbus-auditor:v1
  \____________/ \____________/ \/
     registry      repository   tag

No registry = Docker Hub. No tag = `latest`.

------------------------------------------------------------------------------------------
## 2. The Dockerfile

A Dockerfile is the recipe. Each instruction adds a layer:

```dockerfile
FROM busybox:1.37             # the base image to start from
ARG BUILD=dev                 # build-time variable, set with --build-arg BUILD=v1
ENV BUILD=$BUILD ROLE=unset   # environment variables baked into the image (runtime)
WORKDIR /app                  # working directory for the following instructions
COPY run.sh /run.sh           # copy a file from the build context into the image
RUN chmod +x /run.sh          # run a command at BUILD time
EXPOSE 8080                   # documents the port (doesn't publish anything)
CMD ["sh", "/run.sh"]         # the default command when a container starts
```

  ARG   exists only while building. To keep its value at runtime, copy it into an ENV.
  ENV   is there at runtime: the container's processes see it.
  CMD   default command, replaced by `podman run <image> <cmd>` or a Pod's `args`
  ENTRYPOINT   the executable; CMD then supplies its default arguments

A `#` comment must be on its own line. After an instruction, `#...` becomes part of
the value.

------------------------------------------------------------------------------------------
## 3. Build, tag, push, export

```bash
ssh ckad-build                               # the build host; exit brings you back
cd /path/to/folder-with-Dockerfile
podman build -t localhost:5000/app:v1 .                    # the . is the build context
podman build -t localhost:5000/app:v1 -t localhost:5000/app:latest .   # two tags
podman build --build-arg BUILD=v1 -t localhost:5000/app:v1 .           # set an ARG
podman build -f other.Dockerfile -t app:v2 .               # a Dockerfile with another name

podman images                                # local images (podman image ls)
podman tag localhost:5000/app:v1 localhost:5000/app:stable   # add another tag
podman push localhost:5000/app:v1            # one push PER tag
podman run --rm localhost:5000/app:v1        # quick local test

podman save -o /tmp/app-v1.tar localhost:5000/app:v1   # export the image to a file
podman load -i /tmp/app-v1.tar                         # import it again
exit
```

docker takes the same commands and flags: `docker build -t ...`, `docker push ...`,
`docker save -o ...`. The exam may offer either; podman is the usual one.

------------------------------------------------------------------------------------------
## 4. Running your image in Kubernetes

```bash
k run app -n polaris --image=localhost:5000/app:v1
k get pod app -n polaris
k logs app -n polaris
```

In this lab the cluster pulls `localhost:5000/...` from the same registry you push to. If
the name or tag is wrong, the Pod shows ErrImagePull / ImagePullBackOff;
`k describe pod <name>` shows the exact pull error. With the `:latest` tag Kubernetes
always re-pulls; with other tags it reuses a cached image (imagePullPolicy).

------------------------------------------------------------------------------------------
## 5. How this applies to question 11

  Task 1  Edit the Dockerfile so the ROLE variable gets the requested default value
          (from either host: /opt/course is shared).
  Task 2  On the build host: one build with the build argument and BOTH tags, then push
          each tag.
  Task 3  Back in the terminal: run a Pod from the v1 image (the exact name, including
          registry and tag).
  Task 4  Save the Pod's logs into the file; they should show the new ROLE and BUILD.
  Task 5  On the build host again: export that image as a tar archive to the given path.

------------------------------------------------------------------------------------------
## 6. Common mistakes

  - Forgetting the `.` (build context) at the end of `podman build`
  - Tagging twice but pushing only one tag
  - A comment after an instruction on the same line
  - Expecting an ARG to be visible at runtime without an ENV
  - A typo in the image name in the Pod: ImagePullBackOff
  - Running `kubectl` on the build host, or `podman` in the terminal: check the prompt,
    and `exit` when you're done on the other host

------------------------------------------------------------------------------------------
## 7. Docs

  `podman build --help`, `podman save --help` work on the build host and are always
  available.
  kubernetes.io: search "Images" for image names, tags and imagePullPolicy.

Now try it: ckad q 11
