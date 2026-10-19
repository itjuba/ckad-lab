# Change a running Deployment

Namespace: `pyxis`

The Deployment `pyxis-api` in Namespace `pyxis` is running with 3 replicas. Team Pyxis
needs a few changes before going to production.

1. Add the environment variables `MODE=production` and `LOG_LEVEL=info` to its container.

2. Give the container resource requests of cpu `50m` and memory `64Mi`, and a memory
   limit of `128Mi`.

3. Add the label `version=v2` to the Deployment's **Pod template**, so every new Pod
   carries it.

4. Add the annotation `owner=team-pyxis` to the Deployment itself.

All 3 replicas must be updated and available afterwards.
