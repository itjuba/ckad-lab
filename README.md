# CKAD Lab

Practice for the CKAD exam on a real cluster. The questions are written in the style of the
killer.sh simulator: scenario-based, with existing (sometimes broken) resources, and answers
saved under `/opt/course/<n>/`. Every question is graded against the live cluster, and there's
no timer.

- `sim/`: the simulator (exam terminal image, question runner, questions)
- `test-plan.md`: the original 43 quick drills, with answers inline

The questions are original. This project isn't affiliated with killer.sh, the CNCF or the
Linux Foundation.

## Requirements

Windows with Docker Desktop and [k3d](https://k3d.io) (`winget install k3d.k3d`).
Everything else (kubectl, helm, vim) lives inside the exam terminal. The host script
`sim.ps1` is PowerShell, while everything inside the terminal is plain Linux/bash.

## Use it

From PowerShell in this folder:

```powershell
.\sim.ps1 up       # first time: cluster + registry + terminal + all questions (~5 min)
.\sim.ps1 shell    # open the exam terminal
```

Inside the terminal:

```bash
ckad list          # all questions
ckad q 4           # read question 4
# ...solve it with k / vim / helm...
ckad check 4       # grade question 4, task by task
ckad solution 4    # see how to solve it
ckad reset 4       # put question 4 back to its starting state
ckad check         # grade everything, with a total and the 66% pass mark
```

When you're done for the day:

```powershell
.\sim.ps1 stop     # pause (progress is kept)
.\sim.ps1 start    # resume
.\sim.ps1 reset    # reset every question
.\sim.ps1 down     # delete everything (answer files stay in course/)
```

## Questions

28 questions covering every topic in the official curriculum
([CKAD_Curriculum_v1.37](https://github.com/cncf/curriculum)). `ckad check` scores each
domain separately and weights the total by the exam's domain percentages, so it
reflects how the real exam is scored.

| Domain (exam weight) | Questions |
|---|---|
| Application Design and Build (20%) | 2 Pod + named port · 3 Job · 11 build/push image · 12 static PV · 13 dynamic PVC · 16 native sidecar · 19 CronJob · 24 DaemonSet + init container |
| Application Deployment (20%) | 4 Helm · 8 rollout/rollback · 17 Kustomize · 22 canary · 26 blue/green |
| Application Observability and Maintenance (15%) | 1 inventory · 6 probes · 7 debug crash · 25 `kubectl top` + OOMKilled |
| Application Environment, Configuration and Security (25%) | 5 ServiceAccount + RBAC · 9 securityContext · 14 Secrets · 15 ConfigMap · 21 quota/LimitRange · 23 CRD + API deprecations |
| Services and Networking (20%) | 10 Service + DNS · 18 Ingress · 20 NetworkPolicies · 27 Service debug + NodePort · 28 NetworkPolicy debug |

## The environment

| | |
|---|---|
| Cluster | k3d `ckad`: 1 control plane + 1 worker, Kubernetes v1.37 |
| Ingress | Traefik, `ingressClassName: traefik`, reachable at `http://k3d-ckad-server-0` |
| NodePorts | `http://k3d-ckad-server-0:<nodePort>` |
| Storage | default StorageClass `local-path` (WaitForFirstConsumer) |
| NetworkPolicy | enforced |
| Registry | `docker push localhost:5000/<image>`, and Pods pull the same name |
| Helm repo | `http://localhost:8879` (added as `nimbus` by the Helm question) |
| Answers | `/opt/course/<n>/` in the terminal = `course/<n>/` in this folder |

Like the exam, the terminal has the `k` alias and kubectl completion preset, and nothing else.
Set up `do`/`now` and your vim settings yourself; that's part of the practice.

Differences from the real exam: one cluster instead of several contexts, Traefik instead of
another ingress controller, and docker instead of podman for the image question.

## Adding a question

Create `sim/questions/qNN/` with:

- `question.md`: first line `# Title` (shown in `ckad list`)
- `setup.sh`: creates the starting state; re-runnable, since it's also the reset
- `check.sh`: one `check "description" <command>` per task, ending with `finish`
- `solve.sh`: a non-interactive reference solution
- `solution.md`: the walkthrough shown by `ckad solution`

Helpers live in `sim/lib/common.sh`. `ckad selftest NN` runs setup → check → solve → check and
fails unless the question starts unsolved and ends fully solved.
