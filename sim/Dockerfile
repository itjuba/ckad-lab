# CKAD exam terminal: the Linux shell you practice in, plus the web UI (ckad-ui).

# Web UI, stage 1: the React app
FROM node:22-alpine AS web
WORKDIR /web
COPY ui/web/package.json ui/web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY ui/web/ ./
RUN npm run build

# Web UI, stage 2: the Go server, with the React build embedded
FROM golang:1.25-alpine AS server
WORKDIR /src
COPY ui/server/go.mod ui/server/go.sum ./
RUN go mod download
COPY ui/server/ ./
COPY --from=web /web/dist ./web
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /ckad-ui .

FROM ubuntu:24.04

ARG KUBECTL_VERSION=v1.37.1
ARG HELM_VERSION=v3.20.0
ENV DEBIAN_FRONTEND=noninteractive

# No docker or podman here: like the exam, images are built on the build host (ssh ckad-build).
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion ca-certificates curl dnsutils iputils-ping less nano \
      netcat-openbsd openssh-client python3 tmux vim \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
  && chmod +x /usr/local/bin/kubectl
RUN curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
  | tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm

# Local Helm chart repository served on http://localhost:8879 (see entrypoint.sh)
COPY terminal/build-charts.sh /tmp/build-charts.sh
RUN bash /tmp/build-charts.sh /srv/charts && rm /tmp/build-charts.sh

# Web UI on http://localhost:8090 (started by entrypoint.sh)
COPY --from=server /ckad-ui /usr/local/bin/ckad-ui

# /ckad is the sim/ folder mounted from the host, so edits there are live.
RUN echo '[ -f /ckad/terminal/bashrc ] && source /ckad/terminal/bashrc' >> /root/.bashrc
WORKDIR /root
ENTRYPOINT ["bash", "/ckad/terminal/entrypoint.sh"]
