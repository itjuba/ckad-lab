# Kustomize staging overlay

Namespaces: `sirius`, `sirius-staging`

Team Sirius manages its API with Kustomize. The config is in
`/opt/course/17/kustomize/`: a `base/` and an `overlays/dev/` overlay. The dev
overlay is already deployed to Namespace `sirius`.

1. Create a new overlay `/opt/course/17/kustomize/overlays/staging` that builds on
   the base and:
   - deploys everything into Namespace `sirius-staging`
   - runs `2` replicas of Deployment `sirius-api`
   - uses image `nginx:1.29-alpine`, set with Kustomize's `images` field rather than
     by editing the base
   - adds the label `env=staging` to the resources

2. Deploy the staging overlay with `kubectl apply -k`. Don't change `base/` or
   `overlays/dev/`.
