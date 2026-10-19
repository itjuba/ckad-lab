# Swap a Deployment to an immutable ConfigMap

Namespace: `carina`

The Deployment `carina-gateway` in Namespace `carina` reads its settings as
environment variables from the ConfigMap `gateway-config-v1`. Team Carina wants
new settings, stored in a ConfigMap that nobody can change by accident.

1. Create a ConfigMap named `gateway-config-v2` in Namespace `carina` from the
   env file `/opt/course/15/gateway.env`. Each line of the file must become its
   own key. The ConfigMap must be immutable.

2. Change Deployment `carina-gateway` so its container gets its environment from
   `gateway-config-v2`. `gateway-config-v1` must no longer be referenced.

3. After the rollout, run `env | grep ^GW_ | sort` in one of the new Pods and
   write the output to `/opt/course/15/env.txt`.

4. Delete the ConfigMap `gateway-config-v1`.
