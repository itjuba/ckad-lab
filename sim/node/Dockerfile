# ckad-build: the host you ssh into for the image question. It has podman, like the exam,
# and no kubectl. Based on the podman project's image, made for running podman inside a
# (privileged) container.
FROM quay.io/podman/stable:v5.8

RUN dnf install -y --setopt=install_weak_deps=False openssh-server socat \
  && dnf clean all

# Pods pull localhost:5000/<image>; on this host the same name reaches the registry through
# a local forward (see entrypoint.sh), over plain http.
RUN printf '[[registry]]\nlocation = "localhost:5000"\ninsecure = true\n' \
      >/etc/containers/registries.conf.d/ckad-registry.conf

COPY entrypoint.sh /entrypoint.sh
EXPOSE 22
ENTRYPOINT ["bash", "/entrypoint.sh"]
