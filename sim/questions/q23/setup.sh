#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 23)
reset_ns pollux
kubectl delete crd backups.nimbus.io --ignore-not-found --wait=true --timeout=120s

kubectl apply -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backups.nimbus.io
spec:
  group: nimbus.io
  scope: Namespaced
  names:
    plural: backups
    singular: backup
    kind: Backup
    shortNames: [bk]
  versions:
  - name: v1
    served: true
    storage: true
    additionalPrinterColumns:
    - name: Schedule
      type: string
      jsonPath: .spec.schedule
    - name: Target
      type: string
      jsonPath: .spec.target
    - name: Retention
      type: integer
      jsonPath: .spec.retentionDays
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: [schedule, target]
            properties:
              schedule:
                type: string
                description: Cron expression for when the backup runs.
              retentionDays:
                type: integer
                minimum: 1
                description: How many days backups are kept.
              target:
                type: string
                description: Name of the Deployment to back up.
EOF
kubectl wait --for=condition=Established crd/backups.nimbus.io --timeout=60s

kubectl create deployment pollux-web -n pollux --image=nginx:1.29-alpine --replicas=2
wait_rollout pollux pollux-web

mkdir -p "$D/legacy"
cat >"$D/legacy/hpa.yaml" <<'EOF'
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: pollux-web
  namespace: pollux
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pollux-web
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      targetAverageUtilization: 70
EOF
cat >"$D/legacy/pdb.yaml" <<'EOF'
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: pollux-web
  namespace: pollux
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: pollux-web
EOF
