# Namespace and pod inventory

The platform team at Nimbus is auditing the cluster before a migration.

1. Write the names of all namespaces that carry the label `nimbus.io/team`
   (any value) into `/opt/course/1/team-namespaces`, one name per line.

2. Write the number of Pods, across all namespaces, that have the label
   `tier=frontend` into `/opt/course/1/frontend-pods`. The file contains only
   the number.

3. Write the name of the Node that the Pod with the annotation
   `nimbus.io/role=primary` is running on into `/opt/course/1/primary-node`.
