# CKAD Lab web UI: API contract

The Go server (`sim/ui/server`) runs inside the `ckad-terminal` container on port 8090 and
serves the React app (`sim/ui/web`, built into the binary) plus this API. Same origin, JSON.
It shares state with the `ckad` CLI (`/opt/course/.ckad/`), so both stay in sync.

Errors: non-2xx with `{"error": "message"}`. In exam mode, lessons, solutions and checks
return **403** `{"error": "Exam mode: ... until the end"}`.

## State

`GET /api/state`
```json
{
  "mode": "learn",              // "learn" | "exam"
  "examStartedAt": null,        // unix seconds when the exam started, or null
  "examSeconds": 7200,          // exam length
  "examQuestions": [],          // question numbers of the running exam, in exam order
  "flags": [],                  // exam questions flagged for review
  "passed": [1, 3],             // questions passed in learning mode
  "next": 2,                    // next unpassed question in the learning path, or null
  "total": 42                   // number of questions
}
```

## Course and questions

`GET /api/course`
```json
{
  "lesson0": { "title": "Kubernetes & kubectl fundamentals" },
  "sections": [
    {
      "title": "Pods & kubectl basics",
      "questions": [
        { "n": 1, "title": "Namespace and pod inventory",
          "lesson": "Namespaces, labels, selectors and annotations",
          "domain": "D3", "weight": 2, "context": "ckad-c1", "passed": true }
      ]
    }
  ],
  "domains": {
    "D1": { "name": "Application Design and Build", "short": "Design & Build", "weight": 20 },
    "D2": { "name": "Application Deployment", "short": "Deployment", "weight": 20 },
    "D3": { "name": "Application Observability and Maintenance", "short": "Observability", "weight": 15 },
    "D4": { "name": "Application Environment, Configuration and Security", "short": "Config & Security", "weight": 25 },
    "D5": { "name": "Services and Networking", "short": "Networking", "weight": 20 }
  },
  "contexts": ["ckad-c1", "ckad-c2"]
}
```
`sections` follow the learning path order. Every question appears in exactly one section.
`weight` is the question's task weight (its share of an exam in points; an exam's 18
questions add up to about 100), `context` the kubectl context it is set up and graded in.

`GET /api/questions/{n}`
```json
{ "n": 4, "title": "Helm release management", "domain": "D2", "weight": 7, "context": "ckad-c2",
  "step": 38, "steps": 42, "markdown": "# Helm release management\n..." }
```
`step` is the position in the learning path (null if not in it).

`POST /api/questions/{n}/flag` body `{"flag": true}` (409 outside an exam): flags or
unflags an exam question for review, like the real exam. Returns `/api/state`.

`GET /api/lessons/0` · `GET /api/questions/{n}/lesson` · `GET /api/questions/{n}/solution`
```json
{ "markdown": "# Lesson 4: ..." }
```
403 in exam mode. Lessons are plain-text-friendly markdown (ASCII art, `---` rules, code blocks).

## Grading and reset

`POST /api/questions/{n}/check` (403 in exam mode, takes a few seconds)
```json
{ "n": 4, "tasks": [ { "ok": true, "text": "release vega-legacy is deleted" } ],
  "pass": 7, "total": 8, "passed": false, "next": 4 }
```
`passed` = full marks (then it's recorded as passed). `next` = next unpassed question.

`POST /api/questions/{n}/reset` (takes 5–90 seconds)
```json
{ "ok": true, "log": "...setup output, mostly useful when ok=false..." }
```

## Exam mode

`POST /api/exam/start` body `{"keep": false}`: picks 18 random questions spread by domain,
resets them (unless keep), starts the 2-hour timer. Takes up to ~2 minutes. Returns `/api/state`.

`POST /api/exam/end`: grades the exam's questions and returns to learning mode.
```json
{
  "score": 71, "passedExam": true, "passMark": 66, "timeUsed": 5400,
  "domains": [ { "code": "D1", "name": "Application Design and Build", "short": "Design & Build",
                 "weight": 22, "pass": 20, "total": 30, "percent": 66 } ],
  "questions": [ { "n": 3, "title": "Batch Job ...", "domain": "D1", "weight": 6, "pass": 9, "total": 9,
                   "tasks": [ { "ok": true, "text": "..." } ] } ]
}
```
Scoring is the exam's: each question counts with its task weight and gives partial credit
per task, so `score` = Σ weight × pass/total ÷ Σ weight. `domains` only lists domains that
had questions; a domain's `weight` is its share of this exam's task weight in percent.

`POST /api/exam/abort` → `{ "ok": true }`

`GET /api/exam/history`
```json
{ "entries": [ { "date": "2026-10-20 14:02", "score": 71, "timeUsed": "1:30:00",
                 "questions": [3, 22, 16] } ] }
```
Newest first.

## Terminal

`GET /api/terminal` (WebSocket upgrade). Each connection gets its own bash shell in the exam
terminal (`candidate@ckad:~$`, same tools, k alias, completion).

- client → server: text frames with JSON
  - `{"type":"input","data":"k get po\r"}`
  - `{"type":"resize","cols":120,"rows":32}` (send once right after connecting, and on resize)
- server → client: binary frames with raw terminal output (feed into xterm.js as bytes)
- when the shell exits, the server closes the socket.
