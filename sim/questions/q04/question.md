# Helm release management

Namespace: `vega`

Team Vega deploys its services with Helm. The chart repository `nimbus` is
already configured in this terminal.

1. Delete the release `vega-legacy`.

2. Upgrade the release `vega-api` to version `0.2.0` of the chart
   `nimbus/webapp`. It must run **2** replicas after the upgrade.

3. Install a new release `vega-web` from chart `nimbus/webapp`, chart version
   `0.2.0`, with **3** replicas and a Service of type `NodePort`.

4. One release in Namespace `vega` is broken and has the status `failed`.
   Write its name into `/opt/course/4/failed-release`, then delete that release.
