# DaemonSet with an init container

Namespace: `vela`

Team Vela needs a small agent on every node of the cluster, control plane included.

1. Create a DaemonSet `node-agent` in Namespace `vela`:
   - Pods carry the label `app=node-agent`
   - it must also run on control-plane nodes, so tolerate the taint
     `node-role.kubernetes.io/control-plane` with effect `NoSchedule`
   - an emptyDir volume named `config`, mounted at `/config` in both containers below

2. An init container `init-config` (image `busybox:1.37`) writes the line
   `node=<name of the node the Pod runs on>` into `/config/agent.conf`.
   Get the node name through an environment variable `NODE_NAME` filled from the Pod's
   own spec (Downward API), not hardcoded.

3. The main container `agent` (image `busybox:1.37`) runs
   `sh -c 'cat /config/agent.conf; sleep 1d'`.

4. Once a Pod runs on every node, write the logs of the `agent` container of the Pod on
   node `k3d-ckad-agent-0` into `/opt/course/24/agent.log`.
