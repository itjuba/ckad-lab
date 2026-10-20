# Solution 4

```bash
helm repo list                                   # nimbus is there
helm -n vega ls                                  # deployed + failed releases (-a adds pending/superseded)
helm search repo nimbus/webapp --versions        # 0.1.0 and 0.2.0

# 1.
helm -n vega uninstall vega-legacy

# 2. Find the value names first
helm show values nimbus/webapp --version 0.2.0 | grep replicaCount
helm show values nimbus/webapp --version 0.2.0 | grep -A3 '^service:'   # type: ClusterIP
helm -n vega upgrade vega-api nimbus/webapp --version 0.2.0 --set replicaCount=2
helm -n vega ls

# 3.
helm -n vega install vega-web nimbus/webapp --version 0.2.0 \
  --set replicaCount=3 --set service.type=NodePort
k -n vega get deploy,svc

# 4.
helm -n vega ls --failed -q                      # only failed releases, names only
helm -n vega ls --failed -q > /opt/course/4/failed-release
helm -n vega uninstall vega-canary
```

Remember:
- `helm upgrade` without `--reuse-values` resets every value you don't pass back
  to the chart default.
- Without `--version`, helm installs the newest chart version.
- `helm ls` shows deployed and failed releases. `-a` adds pending, superseded and
  uninstalling ones; `--failed` / `--pending` filter by state; `-q` prints names only.
