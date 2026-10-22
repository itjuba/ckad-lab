# CKAD Lab

A local practice simulator for the **Certified Kubernetes Application Developer (CKAD)** exam.
You solve 42 scenario-based questions in a real Linux terminal against two real Kubernetes
clusters. Each task is graded against the live cluster, and every question comes with a
lesson that teaches the theory first, plus a step-by-step solution. No prior Kubernetes
knowledge needed: start with Lesson 0.

The environment works like the real exam: every question starts with
`kubectl config use-context <name>` and names its **task weight**, the clusters differ, images
are built with **podman on a build host you ssh into**, and the mock exam is scored the way
the exam is (each question by its weight, partial credit per task). The questions are written
in the style of the killer.sh simulator: existing (sometimes broken) resources to find and
fix, several steps per question, and answers saved under `/opt/course/<n>/`. They are
original. This project isn't affiliated with killer.sh, the CNCF or the Linux Foundation.

**Contents:**
[Quick start](#quick-start) ·
[Web UI](#web-ui) ·
[The course](#the-course) ·
[Practice mode](#practice-mode) ·
[Exam mode](#exam-mode) ·
[How grading works](#how-grading-works) ·
[Command reference](#command-reference) ·
[Questions](#questions) ·
[The environment](#the-environment) ·
[Exam tips](#exam-tips) ·
[Troubleshooting](#troubleshooting) ·
[Repository layout](#repository-layout) ·
[Adding a question](#adding-a-question)

---

## Quick start

**Requirements:** Windows with [Docker Desktop](https://www.docker.com/products/docker-desktop/)
running (give it 6 GB of memory or more: two clusters and a build host) and
[k3d](https://k3d.io) (`winget install k3d.k3d`). Everything else (kubectl, helm, podman, vim)
lives inside the exam environment.

From PowerShell in this folder:

```powershell
.\sim.ps1 up       # first time only: clusters + registry + build host + terminal + all questions (~6 min)
.\sim.ps1 shell    # open the exam terminal
```

You land in a Linux shell (`candidate@ckad:~$`). New to Kubernetes? Start with the course:

```bash
ckad course                              # the course outline
ckad explain 0                           # Lesson 0: Kubernetes & kubectl fundamentals
export do="--dry-run=client -o yaml"     # set these at the start of every session,
export now="--force --grace-period=0"    # like on the real exam
ckad next                                # the first question
kubectl config use-context ckad-c1       # ...which starts, like every question, with its context
```

When you're done for the day, `exit` the terminal and run `.\sim.ps1 stop`. Next time, run
`.\sim.ps1 start` and then `.\sim.ps1 shell`. Your progress is kept.

### Or: Docker Compose (Linux, macOS, Windows)

The same simulator with nothing but Docker: no PowerShell, no k3d. Compose runs the two
clusters (k3s: a server and a worker for `ckad-c1`, one server for `ckad-c2`), the image
registry, the build host, and the exam terminal with the web UI.

```bash
docker compose up -d               # first time: build + set up every question (~5 min)
docker compose logs -f setup       # follow the first-time setup until "Ready"
docker compose exec terminal bash  # the exam terminal, or open http://localhost:8090
```

| Command | What it does |
|---|---|
| `docker compose stop` / `start` | pause / resume; your work is kept |
| `docker compose build && docker compose up -d` | after `git pull`: rebuild the terminal and build host, keep your work |
| `docker compose exec terminal ckad reset all` | put every question back to its starting state |
| `docker compose down` | remove the containers; the cluster's data is kept in volumes |
| `docker compose down -v` | delete everything, cluster included (the next `up` starts fresh) |

The questions are set up only on the first `up`. A marker in the cluster records it, so
running `up` again never resets your work. Answers and progress are in `course/`, like with
`sim.ps1`. **Use one or the other, not both at once.** They need the same ports
(8090, 5000), and the first `docker compose up` sets every question up from scratch, which
clears the answer files in `course/`. To run both side by side, set `CKAD_UI_PORT`,
`CKAD_REGISTRY_PORT` and `CKAD_COURSE_DIR` to other values, and use another project name
(`docker compose -p other-name ...`).

---

## Web UI

Prefer a browser? After `.\sim.ps1 up`, open **http://localhost:8090**, or run `.\sim.ps1 ui`.
It's laid out like the real exam: the question on the left, a live terminal on the right.

- **The question page reads like the exam's**: the context to switch to first
  (`kubectl config use-context …`, one click copies it), the task weight, then the task.
- **Question / Lesson / Solution tabs**, with the solution revealed only when you ask.
- **A real terminal** (xterm.js): each browser terminal is its own bash session in the same
  exam environment as `.\sim.ps1 shell`, with the same tools, `k` alias and completion.
- **Check** grades the question task by task (✔/✘). **Reset** restores it.
  **Prev/Next** follow the learning path.
- **Course drawer**: Lesson 0 and every question in learning order, with your progress.
- **Exam mode**: start a mock exam (18 random questions, 2-hour countdown in the top bar),
  **flag** questions to come back to, end it to get the weighted score with per-domain and
  per-question results, and look back at your exam history.
- **One-click copy, like the exam**: click a name or path in the question (anything in
  `code` style) to copy it, then paste it in the terminal with `Ctrl+Shift+V`. Copying avoids
  the typos that cost points.
- Shortcuts: `Ctrl+Enter` = Check, `Alt+←/→` = previous/next question.
- **Black and white**: black by default, white with the ☀/☾ toggle (remembered). The terminal
  stays black in both, like the exam's. The only colors are ✔/✘ results and timer warnings.

The UI and the `ckad` CLI share the same progress and exam state, so you can switch between
them at any time. The UI listens on `127.0.0.1` only and refuses cross-site requests, because
its terminal is a real shell.

After pulling a new version of this repo, run `.\sim.ps1 update` to rebuild the terminal image
with the latest UI. Your cluster, answers and progress stay as they are.

---

## The course

Every question has a **lesson** that teaches its topic from scratch before you attempt it:

1. The problem the feature solves, with a real-world example
2. The theory: what each piece is and how the pieces connect
3. How it works: small YAML examples with every important line commented
4. The commands you need for it
5. How it applies to that question, task by task, without giving the answer away
6. Common mistakes, and the kubernetes.io docs pages to use on the exam

**Lesson 0** covers the foundation every question builds on: the cluster, objects, YAML,
namespaces, labels and selectors, the core kubectl commands, the generate → edit → apply
workflow, and reading what went wrong.

```bash
ckad course          # Lesson 0 + every lesson in learning order, with your progress
ckad explain 0       # Lesson 0: Kubernetes & kubectl fundamentals (read once)
ckad explain 29      # the lesson for question 29 (scroll with space/arrows, q to quit)
```

The study loop for each step: **`ckad explain N` → `ckad q N` → solve → `ckad check N`**,
and `ckad solution N` only if you're stuck.

---

## Practice mode

This is the default mode, for practicing topic by topic in the exam's environment.

- Questions follow a **basics-first learning path**: Pods, then Deployments, Jobs, storage,
  configuration, Services, debugging, security, deployment strategies, tools, NetworkPolicies
  and CRDs.
- Every question is presented like an exam task: **context first**, then its task weight,
  then the steps. Grading always runs in the question's context, so a Deployment created in
  the wrong cluster scores 0, exactly like the exam.
- Lessons (`ckad explain <n>`), grading (`ckad check <n>`) and solutions
  (`ckad solution <n>`) are available any time.
- Full marks on a question **marks it passed**. `ckad list` shows ✔ for passed questions and
  ▶ for your next one, and `ckad next` always opens the next unpassed question.
- `ckad reset <n>` puts a question back to its starting state, so you can repeat it until
  you're fast.

```bash
ckad explain 29    # learn the topic first
ckad next          # read the next question
# ...solve it with k / nano / helm / podman...
ckad check 29      # grade it task by task
ckad solution 29   # compare with the reference solution
ckad list          # see the whole path and your progress
```

### The learning path

| Section | Questions |
|---|---|
| Pods & kubectl basics | 1 → 2 → 29 → 30 |
| Deployments | 31 → 32 → 8 |
| Jobs & other workloads | 3 → 33 → 19 → 34 → 35 → 36 → 24 → 16 |
| Storage | 12 → 13 |
| Configuration | 15 → 37 → 14 → 38 |
| Services & Ingress | 10 → 39 → 27 → 18 |
| Observability & debugging | 6 → 7 → 40 → 25 |
| Resources & security | 42 → 21 → 9 → 41 → 5 |
| Deployment strategies | 26 → 22 |
| Tools | 11 → 4 → 17 |
| NetworkPolicies | 20 → 28 |
| Extending Kubernetes | 23 |

The order is defined in [`sim/learning-path`](sim/learning-path). Edit it to change the order;
`## ` lines become section headings in `ckad list`.

---

## Exam mode

A 2-hour mock exam that works like the real one.

```bash
ckad exam start    # pick 18 random questions, reset them, start the timer
ckad list          # the exam's questions, in mixed order, with weights and flags
ckad q 23          # read one: context, task weight, tasks
ckad flag 23       # flag it to come back to it (again to unflag)
ckad exam          # time left
ckad exam end      # grade everything, show the final score, return to practice mode
```

- **18 random questions per run**, spread across the domains like the real exam (which has
  about 16–20 tasks): 4 Design & Build, 4 Deployment, 3 Observability, 4 Config & Security and
  3 Networking. Every run is different.
- **Task weights**, shown on every question as its share of this exam (they add up to 100%).
- **Timer in your prompt**, for example `[exam 1:42] candidate@ckad:~$`.
- **No grading, lessons or solutions until the end**, like the real exam. `ckad check`,
  `ckad explain` and `ckad solution` are locked while the exam runs.
- **`ckad exam end`** grades all 18 questions and scores them like the exam: each question
  counts by its task weight, with partial credit per task, against the 66% pass mark. You also
  get each domain's share and score.
- **`ckad exam history`** lists your past scores, time used and which questions you got.
- `ckad exam start --keep` starts the timer without resetting the picked questions.
  `ckad exam abort` stops without grading.

---

## How grading works

The grader checks **results, never the commands you typed**, just like the real exam:

- **Files**: does `/opt/course/<n>/<file>` contain the right answer? Typing the value by hand
  is just as valid as generating it with a command.
- **The cluster**: does the resource exist, with the right fields? Is it Running? Does the
  Service have endpoints? Can Pod A reach Pod B?

One exception: when a task asks you to write a **command or script** into a file, the file
must contain a working command, because the grader runs it.

Graders accept every valid approach: imperative or YAML, named or numeric ports, a
`namespace/` prefix from `-o name`, trailing whitespace. Each question scores 0 until you've
actually done the work.

**Scoring is the exam's.** Each question has a task weight (`sim/questions/qNN/weight`, set
so that an exam's 18 questions add up to about 100). A question earns its weight times the
share of its tasks you got right, and the score is the earned weight over the total weight.
`ckad check` with no number grades every question this way, grouped by curriculum domain
(example output):

```
  Domain                    Weight     Tasks  Score
  Design & Build               32%   62/86      72%
  Deployment                   17%   30/44      68%
  ...
  Score: 71%  ✔ PASS  (pass mark 66%; 180/251 tasks, weighted by task)
```

**Grading runs in the question's context**, whatever context your terminal is on, so
resources created in the wrong cluster don't count.

---

## Command reference

**In the exam terminal**

| Command | What it does |
|---|---|
| `ckad course` | the course outline: Lesson 0 + every lesson in learning order |
| `ckad explain <n>` | the lesson for question n (`ckad explain 0` = fundamentals) |
| `ckad next` | show the next unpassed question in the learning path |
| `ckad list` | learning path + progress (in exam mode: the exam's questions) |
| `ckad q <n>` | show question n |
| `ckad check <n>` | grade question n task by task, in its context (practice mode) |
| `ckad check` | grade every question with the exam's weighted score |
| `ckad solution <n>` | show the walkthrough for question n |
| `ckad reset <n>` / `ckad reset all` | restore question n (or all) to its starting state |
| `ckad progress clear` | forget which questions you passed |
| `ckad exam start [--keep]` | start a mock exam |
| `ckad exam` | exam time left |
| `ckad flag <n>` | flag exam question n for review (again to unflag) |
| `ckad exam end` / `ckad exam abort` | finish with grading / stop without grading |
| `ckad exam history` | past exam scores |
| `ckad help` | all commands |

**In PowerShell (host)**

| Command | What it does |
|---|---|
| `.\sim.ps1 up` | create clusters, registry, build host and terminal, then set up all questions |
| `.\sim.ps1 ui` | open the web UI at http://localhost:8090 |
| `.\sim.ps1 shell` | open the exam terminal |
| `.\sim.ps1 update` | bring the environment up to date after `git pull` (images, missing cluster or build host); keeps your work |
| `.\sim.ps1 stop` / `start` | pause / resume everything (progress is kept) |
| `.\sim.ps1 reset` | reset every question |
| `.\sim.ps1 status` | show cluster, build host and terminal state |
| `.\sim.ps1 down` | delete clusters, registry, build host and terminal (answer files stay in `course/`) |

---

## Questions

42 questions cover every topic in the official curriculum
([CKAD_Curriculum_v1.37](https://github.com/cncf/curriculum)):

| Domain (exam weight) | Questions |
|---|---|
| Application Design and Build (20%) | 2 Pod + named port · 3 Job · 11 build/push/export image (podman, on the build host) · 12 static PV · 13 dynamic PVC · 16 native sidecar · 19 CronJob · 24 DaemonSet + init container · 29 command/args/env · 33 failing Job · 34 suspended CronJob · 35 init container · 36 two-container Pod |
| Application Deployment (20%) | 4 Helm · 8 rollout/rollback · 17 Kustomize · 22 canary · 26 blue/green · 31 Deployment basics · 32 change a running Deployment |
| Application Observability and Maintenance (15%) | 1 inventory · 6 probes · 7 debug crash · 25 `kubectl top` + OOMKilled · 30 logs + exec · 40 Pending Pods |
| Application Environment, Configuration and Security (25%) | 5 ServiceAccount + RBAC · 9 securityContext · 14 Secrets · 15 ConfigMap · 21 quota/LimitRange · 23 CRD + API deprecations · 37 ConfigMap as files · 38 Secrets into env · 41 dedicated ServiceAccount · 42 requests/limits + QoS |
| Services and Networking (20%) | 10 Service + DNS · 18 Ingress · 20 NetworkPolicies · 27 Service debug + NodePort · 28 NetworkPolicy debug · 39 two-port Service |

Solutions lead with exam-style techniques: imperative commands with `$do` plus vim edits,
`kubectl set ...`, `describe | grep`, `--no-headers | wc -l / awk`, and `less` + `/search`.
None of them need JSONPath or regex.

---

## The environment

| | |
|---|---|
| Clusters | **Kubernetes v1.37** (the current CKAD version). Context `ckad-c1`: k3d `ckad`, 1 control plane + 1 worker. Context `ckad-c2`: k3d `ckad2`, 1 node. Each question names its context (`sim/contexts`, `sim/questions/qNN/context`) |
| Terminal | Ubuntu with kubectl 1.37, helm 3, vim (the default editor, as on the exam), nano, ssh. No docker or podman: images are built on the build host |
| Build host | `ssh ckad-build`: podman, no kubectl, the same `/opt/course`. `exit` brings you back |
| Ingress | Traefik on `ckad-c1`, `ingressClassName: traefik`, reachable at `http://k3d-ckad-server-0` |
| NodePorts | `http://k3d-ckad-server-0:<nodePort>` (cluster 1) |
| Storage | default StorageClass `local-path` (WaitForFirstConsumer) |
| NetworkPolicy | enforced |
| Metrics | metrics-server, so `kubectl top` works |
| Registry | `podman push localhost:5000/<image>` on the build host, and Pods pull the same name |
| Helm repo | `http://localhost:8879` (added as `nimbus` by the Helm question) |
| Answers | `/opt/course/<n>/` in the terminal = `course/<n>/` in this folder |

Like the exam, the terminal presets only the `k` alias and kubectl completion. Set up `do`,
`now` and your editor yourself; that's part of the practice.

**Differences from the real exam:** Traefik instead of another ingress controller, and no
remote-desktop environment (practice in one browser window, with kubernetes.io as your only
other tab, to get close). Shortly before your exam, also use the two killer.sh sessions that
come with exam registration.

---

## Exam tips

- **Start every session** with `export do="--dry-run=client -o yaml"`,
  `export now="--force --grace-period=0"` and, if you want nano, `export KUBE_EDITOR=nano`.
- **Start every question** with its `kubectl config use-context …` line. Working in the
  wrong cluster is the classic way to lose a whole question.
- **On another host** (`ssh ckad-build`), do only that host's part and `exit` before the
  next step. `kubectl` isn't there; the prompt shows where you are.
- **Generate, edit, apply**: `k create deploy web --image=nginx $do > web.yaml`, then
  `vim web.yaml`, then `k apply -f web.yaml`. Copy only the missing snippet (probe, volume,
  securityContext) from kubernetes.io.
- **Editor setup**: like the exam, `k edit` opens vim unless you say otherwise. If you prefer
  nano, make `export KUBE_EDITOR=nano` part of your session start, together with `do` and
  `now`, and put `set tabsize 2` and `set tabstospaces` in `~/.nanorc`. For vim, `~/.vimrc`:
  `set expandtab tabstop=2 shiftwidth=2`, and `:set paste` before pasting.
- **`k explain`** is often faster than the docs: `k explain pod.spec.containers.livenessProbe`.
- **Events in v1.37**: `kubectl describe` only shows Events when it targets **one object by
  name**. With `-l` or several objects they're hidden, so use the name, `--show-events=true`,
  or `k get events`.
- **Labels, not annotations**: `-l key` matches "label exists". Annotations can't be selected,
  so read them with `describe` or `less` + `/search`.
- **Check what exists first**: `k get all -n <namespace>` at the start of each question.
- **Pasting in the exam terminal**: `Ctrl+Shift+C` / `Ctrl+Shift+V` (plain `Ctrl+C` stops a
  command).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `.\sim.ps1 shell` says there's no terminal | run `.\sim.ps1 up` (first time) or `.\sim.ps1 start` (after a stop or reboot) |
| Commands hang or the cluster is unreachable | make sure Docker Desktop is running, then `.\sim.ps1 start` |
| `ckad check` says 0 tasks although you did the work | you worked in the wrong context: `kubectl config current-context` vs the question's line |
| `ssh ckad-build` fails or asks for a password | the build host isn't up or its key wasn't picked up: `.\sim.ps1 start`, or `.\sim.ps1 update` after a `git pull` |
| `podman build` fails on the build host | `.\sim.ps1 update` rebuilds the build host; the question's `/opt/course/11/image` must exist (`ckad reset 11`) |
| `ckad reset <n>` prints "setup failed" | read the log at `/tmp/ckad-logs/setup-<n>.log` in the terminal and run the reset again |
| A question is in a weird state | `ckad reset <n>` |
| Start everything over | `.\sim.ps1 reset` (questions) and `ckad progress clear` (learning progress) |
| `ckad check` is locked | you're in exam mode: `ckad exam end` (with grading) or `ckad exam abort` |
| http://localhost:8090 doesn't load | `.\sim.ps1 update` (older terminals don't publish the port). The server log is `/tmp/ckad-ui.log` in the terminal |
| The browser terminal says "Disconnected" | click Reconnect. Each session is a fresh shell; your cluster work is kept |
| Something is badly broken | `.\sim.ps1 down`, then `.\sim.ps1 up` |

---

## Repository layout

```
ckad-lab/
├── sim.ps1                 host script: up / shell / stop / start / reset / down
├── compose.yaml            the same simulator with Docker Compose (any OS)
├── test-plan.md            43 quick drills with answers inline
├── course/                 your answer files (= /opt/course in the terminal), git-ignored
└── sim/
    ├── Dockerfile          exam terminal image
    ├── contexts            the kubectl contexts (ckad-c1, ckad-c2) and their clusters
    ├── learning-path       order of questions in practice mode
    ├── bin/ckad            the question runner
    ├── lib/common.sh       helpers for setup/check/solve scripts
    ├── terminal/           bashrc, entrypoint, kubeconfig builder, local Helm chart repo, Compose setup
    ├── node/               the build host image (podman + sshd)
    ├── compose/            k3s registry config for Docker Compose
    ├── ui/                 web UI: Go server (ui/server), React app (ui/web), API.md,
    │                       Playwright tests (ui/web/tests)
    ├── course/             Lesson 0 (fundamentals)
    └── questions/qNN/      one folder per question (question, lesson, solution, grader)
```

---

## Adding a question

Create `sim/questions/qNN/` with:

- `question.md`: first line `# Title` (shown in `ckad list`)
- `setup.sh`: creates the starting state; re-runnable, since it's also the reset
- `check.sh`: one `check "description" <command>` per task, ending with `finish`
- `solve.sh`: a non-interactive reference solution
- `explain.md`: the lesson shown by `ckad explain` (theory first; ASCII, lines ≤ 92 chars)
- `solution.md`: the walkthrough shown by `ckad solution`
- `domain`: `D1`–`D5`, the curriculum domain (used to compose exams and group results)
- `weight`: the task weight, 2–8 (an exam's 18 questions should add up to about 100)
- `context`: `ckad-c1` or `ckad-c2`. Questions that need the worker node, the Ingress, a
  NodePort or the registry belong on `ckad-c1`

Then add its number to `sim/learning-path`.

Helpers live in `sim/lib/common.sh`. The runner executes `setup.sh`, `check.sh` and `solve.sh`
with `KUBECONFIG` pinned to the question's context, so plain `kubectl` in them is right.
`ckad selftest NN` runs setup → check → solve → check and fails unless the question starts at
0 and ends with full marks. Ground rules: state everything the grader checks in the question,
accept every valid approach, and don't give points for work that hasn't been done.

---

## Testing the web UI

Playwright tests live in `sim/ui/web/tests`. One-time setup:

```powershell
cd sim\ui\web
npm install
npx playwright install chromium
```

| Command | What it tests |
|---|---|
| `npm run test:mock` | The React app (a production build) against a fake API and terminal: navigation, tabs, Check/Reset, exam start/end/abort, timer, history, terminal I/O and reconnect, theme, layout, and WCAG 2.1 AA accessibility (axe, including contrast) in both themes. No cluster needed; runs in CI on every push. |
| `npm run test:live` | Your running simulator on http://127.0.0.1:8090 (`CKAD_UI_URL` to change it): every question, lesson and solution loads, the security guards (cross-site requests, foreign Host headers, terminal origin), a real shell running `kubectl`, and grading. Skipped when the simulator isn't up. |
| `npm test` | Both. |
| `npm run test:report` | Opens the HTML report (with traces of failed tests). |

The live tests are read-only: they never reset a question or start an exam. The one thing that
can change is Check: it grades the current question, so a question you've fully solved gets
recorded as passed, as if you had pressed Check yourself.
