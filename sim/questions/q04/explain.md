# Lesson 4: Helm, installing and managing packaged apps

Curriculum: "Use the Helm package manager to deploy existing packages"
(Application Deployment, 20%). On the CKAD you USE existing charts; you never write one.

------------------------------------------------------------------------------------------
## 1. The problem Helm solves

A real app is many objects: Deployment, Service, ConfigMap, ServiceAccount, Ingress...
Copying a dozen YAML files per environment and editing values by hand is error-prone.
Helm packages them so you can install, upgrade and remove the whole app with one command,
like `apt` or `npm` for Kubernetes.

------------------------------------------------------------------------------------------
## 2. The four words you need

  Chart        a package: YAML templates with placeholders, plus default values
  Repository   a server that hosts charts (here: `nimbus`, already added)
  Release      ONE installed copy of a chart, with its own name, in one namespace
  Values       the settings filled into the templates (replicaCount, image.tag, ...)

  chart nimbus/webapp  +  your values  ->  helm install vega-web  ->  Deployment, Service...

The same chart can be installed many times as different releases. Each install, upgrade
or rollback creates a new REVISION of that release.

------------------------------------------------------------------------------------------
## 3. Finding charts and their settings

```bash
helm repo list                                  # configured repositories
helm repo update                                # refresh their chart lists
helm search repo nimbus                         # charts in the repo
helm search repo nimbus/webapp --versions       # every version of one chart
helm show values nimbus/webapp | less           # the settings the chart accepts
helm show values nimbus/webapp --version 0.2.0 | grep replicaCount
```

Value names come from the CHART, not from Kubernetes. Always check `helm show values`.
Nested values are written with dots on the command line:

```yaml
replicaCount: 1        # --set replicaCount=3
service:
  type: ClusterIP      # --set service.type=NodePort
```

------------------------------------------------------------------------------------------
## 4. Managing releases

```bash
# install: release name, chart, namespace, version, values
helm install my-web nimbus/webapp -n vega --version 0.2.0 --set replicaCount=3
helm install my-web nimbus/webapp -n vega -f my-values.yaml    # values from a file
helm install my-web nimbus/webapp -n new-ns --create-namespace

# list
helm list -n vega            # deployed AND failed releases
helm list -n vega -a         # also pending, superseded, uninstalling
helm list -n vega --failed   # only failed ones   (--pending works the same)
helm list -n vega -q         # names only
helm list -A                 # all namespaces

# change
helm upgrade my-web nimbus/webapp -n vega --version 0.2.0 --set replicaCount=2
helm upgrade --install my-web nimbus/webapp -n vega     # install if it doesn't exist
helm history my-web -n vega                              # revisions
helm rollback my-web 1 -n vega                           # back to revision 1
helm uninstall my-web -n vega                            # delete the release

# inspect
helm status my-web -n vega
helm get values my-web -n vega          # values YOU set
helm get values my-web -n vega --all    # all values, including chart defaults
```

Helm creates normal Kubernetes objects, so `k get deploy,svc -n vega` shows the result.
The chart decides their names (often `<release>-<chart>`, like `vega-api-webapp`).

------------------------------------------------------------------------------------------
## 5. Two upgrade rules that cost points

  1. Without `--version`, install/upgrade takes the NEWEST chart version.
  2. `helm upgrade` resets every value you don't pass again back to the chart default.
     If the old release had replicaCount=5 and you upgrade with only --set image.tag=x,
     replicaCount drops back to 1. Pass every value you need, or use --reuse-values.

------------------------------------------------------------------------------------------
## 6. How this applies to question 4

  Task 1  One uninstall. Remember -n.
  Task 2  Upgrade the existing release to a SPECIFIC chart version and set the replica
          value in the same command. Check the value's name with `helm show values`.
  Task 3  A new install: release name, chart, version, and two values (one is nested
          under `service`). Verify with `k get deploy,svc -n vega`.
  Task 4  List the releases and look at STATUS (or filter for failed ones). Write only
          the name to the file, then uninstall that release too.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - Forgetting `-n vega`: helm looks in `default` and finds nothing
  - Upgrading without `--version` (you get the newest, maybe not the one asked for)
  - Guessing value names (`replicas` instead of `replicaCount`)
  - Writing the release name but forgetting the second half of the task (deleting it)
  - `helm list -n vega failed`: helm list takes no arguments; filters are flags

------------------------------------------------------------------------------------------
## 8. Docs

  `helm <command> --help` always works in the terminal and has examples.
  helm.sh/docs: "Using Helm" and the "Helm Commands" reference. Check the Linux
  Foundation's allowed-resources list for whether helm.sh is allowed on your exam.

Now try it: ckad q 4
