# Secrets from files as environment variables

Namespace: `norma`

Team Norma's worker needs a database address and an API key, provided as Secrets.

1. Create a Secret `norma-api` in Namespace `norma` from the file
   `/opt/course/38/api-key.txt`, stored under the key `api-key`.

2. Create a Secret `norma-db` from the env file `/opt/course/38/db.env`, so that each line
   becomes its own key (`DB_HOST`, `DB_PORT`).

3. Create a Deployment `norma-worker` in `norma` (image `busybox:1.37`, command `sleep 1d`,
   1 replica) whose container gets:
   - every key of `norma-db` as an environment variable, using `envFrom`
   - an environment variable `API_KEY` from the key `api-key` of Secret `norma-api`

4. Run `env | grep -e DB_ -e API_KEY | sort` in the Deployment's Pod and write the output to
   `/opt/course/38/env.txt`.
