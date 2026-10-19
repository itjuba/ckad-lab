# CKAD exam terminal: the Linux shell you practice in.
FROM ubuntu:24.04

ARG KUBECTL_VERSION=v1.37.1
ARG HELM_VERSION=v3.20.0
ARG DOCKER_VERSION=28.4.0
ARG BUILDX_VERSION=v0.38.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion ca-certificates curl dnsutils iputils-ping less nano \
      netcat-openbsd python3 tmux vim \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
  && chmod +x /usr/local/bin/kubectl
RUN curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
  | tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
  | tar -xz -C /usr/local/bin --strip-components=1 docker/docker
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
  && curl -fsSLo /usr/local/lib/docker/cli-plugins/docker-buildx \
     https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64 \
  && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Local Helm chart repository served on http://localhost:8879 (see entrypoint.sh)
COPY terminal/build-charts.sh /tmp/build-charts.sh
RUN bash /tmp/build-charts.sh /srv/charts && rm /tmp/build-charts.sh

# /ckad is the sim/ folder mounted from the host, so edits there are live.
RUN echo '[ -f /ckad/terminal/bashrc ] && source /ckad/terminal/bashrc' >> /root/.bashrc
WORKDIR /root
ENTRYPOINT ["bash", "/ckad/terminal/entrypoint.sh"]
