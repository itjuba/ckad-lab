# Secrets as env vars and as a projected file

Namespace: `pegasus`

Team Pegasus is moving its database client into Kubernetes. Credentials and the
CA certificate must come from Secrets, not from the image.

1. Create a Secret named `db-credentials` in Namespace `pegasus` with two keys:
   - `user` = `pegasus-app`
   - `password` = `Sup3rS3cret!`

2. The security team left a Secret manifest at `/opt/course/14/tls-bundle.yaml`.
   Create that Secret in Namespace `pegasus`.

3. Create a Pod named `db-client` in Namespace `pegasus`, image `busybox:1.37`,
   that runs `sleep 1d`:
   - env var `DB_USER` from key `user` of Secret `db-credentials`
   - env var `DB_PASSWORD` from key `password` of Secret `db-credentials`
   - Secret `tls-bundle` mounted read-only at `/etc/tls`. Only the key `ca.crt`
     may appear there, as the file `/etc/tls/ca.pem`, with file mode `0400`.
