// A fake CKAD Lab server for the mocked tests: the API from sim/ui/API.md and the terminal
// WebSocket, both intercepted in the browser. No cluster or Go server is involved.
import { test as base, expect, type Page, type WebSocketRoute } from '@playwright/test'
import type { CheckResult, ExamResult, HistoryEntry, State } from '../../src/api'
import {
  allQuestions,
  checkResult,
  course,
  examQuestions,
  examResult,
  learningPath,
  lesson0Markdown,
  lessonMarkdown,
  questionMarkdown,
  solutionMarkdown,
} from './data'

export interface Req {
  method: string
  path: string
  body: unknown
}

// 'offline' aborts the request like a server that isn't running.
export type Reply = { status?: number; json?: unknown } | 'offline'
export type Handler = (req: Req) => Reply | Promise<Reply>

interface TermMessage {
  type: 'input' | 'resize'
  data?: string
  cols?: number
  rows?: number
}

interface Connection {
  ws: WebSocketRoute
  messages: TermMessage[]
  closed: boolean
}

export const PROMPT = 'candidate@ckad:~$ '

// MockTerminal plays a tiny shell: it echoes keystrokes like a pty and answers a few commands.
export class MockTerminal {
  connections: Connection[] = []

  // The live connection (React StrictMode opens and drops one extra socket in dev).
  get current(): Connection | undefined {
    return this.connections.filter((c) => !c.closed).at(-1)
  }

  get input(): string {
    return this.connections
      .flatMap((c) => c.messages)
      .filter((m) => m.type === 'input')
      .map((m) => m.data)
      .join('')
  }

  connect(ws: WebSocketRoute) {
    const conn: Connection = { ws, messages: [], closed: false }
    this.connections.push(conn)
    let line = ''
    ws.onClose(() => {
      conn.closed = true
    })
    ws.onMessage((raw) => {
      const m = JSON.parse(String(raw)) as TermMessage
      conn.messages.push(m)
      if (m.type !== 'input' || !m.data) return
      for (const ch of m.data) {
        if (ch === '\r') {
          ws.send(Buffer.from('\r\n' + run(line) + PROMPT))
          line = ''
        } else {
          line += ch
          ws.send(Buffer.from(ch))
        }
      }
    })
    ws.send(Buffer.from(PROMPT))
  }

  // Ends the current shell, like typing `exit`.
  close() {
    const c = this.current
    if (!c) throw new Error('no open terminal connection')
    c.closed = true
    return c.ws.close({ code: 1000, reason: 'shell exited' })
  }
}

function run(cmd: string): string {
  const c = cmd.trim()
  if (c === '') return ''
  if (c.startsWith('echo ')) return c.slice(5) + '\r\n'
  if (/^k(ubectl)? get /.test(c)) return 'No resources found in default namespace.\r\n'
  return `bash: ${c.split(' ')[0]}: command not found\r\n`
}

export class MockApi {
  state: Omit<State, 'next' | 'total'> = {
    mode: 'learn',
    examStartedAt: null,
    examSeconds: 7200,
    examQuestions: [],
    flags: [],
    passed: [],
  }
  // Grading results per question; questions not listed get 2 of 3 tasks.
  checks: Record<number, CheckResult> = {}
  examResult: ExamResult = examResult
  history: HistoryEntry[] = []
  offline = false
  calls: Req[] = []
  unhandled: string[] = []
  terminal = new MockTerminal()
  private overrides = new Map<string, Handler>()

  // Replaces the reply for one endpoint, e.g. 'POST /api/questions/1/check'.
  on(key: string, handler: Handler) {
    this.overrides.set(key, handler)
  }

  callsTo(key: string): Req[] {
    return this.calls.filter((c) => `${c.method} ${c.path}` === key)
  }

  // Puts the server in exam mode, as if `ckad exam start` ran `secondsAgo` seconds ago.
  startExam(secondsAgo = 60) {
    this.state.mode = 'exam'
    this.state.examStartedAt = Math.floor(Date.now() / 1000) - secondsAgo
    this.state.examQuestions = [...examQuestions]
    this.state.flags = []
  }

  stopExam() {
    this.state.mode = 'learn'
    this.state.examStartedAt = null
    this.state.examQuestions = []
    this.state.flags = []
  }

  stateJson(): State {
    return {
      ...this.state,
      passed: [...this.state.passed],
      examQuestions: [...this.state.examQuestions],
      flags: [...this.state.flags],
      next: learningPath.find((n) => !this.state.passed.includes(n)) ?? null,
      total: learningPath.length,
    }
  }

  async attach(page: Page) {
    await page.route(
      (url) => url.pathname.startsWith('/api/'),
      async (route) => {
        const request = route.request()
        const req: Req = {
          method: request.method(),
          path: new URL(request.url()).pathname,
          body: request.postData() ? request.postDataJSON() : undefined,
        }
        this.calls.push(req)
        const reply = this.offline ? 'offline' : await (this.overrides.get(`${req.method} ${req.path}`) ?? this.builtin)(req)
        if (reply === 'offline') await route.abort('connectionrefused')
        else await route.fulfill({ status: reply.status ?? 200, json: reply.json })
      },
    )
    await page.routeWebSocket(
      (url) => url.pathname === '/api/terminal',
      (ws) => this.terminal.connect(ws),
    )
  }

  private builtin: Handler = ({ method, path, body }) => {
    const inExam = this.state.mode === 'exam'
    const blocked = (what: string): Reply => ({
      status: 403,
      json: { error: `Exam mode: no ${what} until the end, like the real exam` },
    })
    const key = `${method} ${path}`

    if (key === 'GET /api/state') return { json: this.stateJson() }
    if (key === 'GET /api/course') return { json: course(this.state.passed) }
    if (key === 'GET /api/lessons/0') return inExam ? blocked('lessons') : { json: { markdown: lesson0Markdown } }
    if (key === 'GET /api/exam/history') return { json: { entries: this.history } }
    if (key === 'POST /api/exam/start') {
      if (inExam) return { status: 409, json: { error: 'an exam is already running; end it first' } }
      this.startExam(0)
      return { json: this.stateJson() }
    }
    if (key === 'POST /api/exam/end') {
      if (!inExam) return { status: 409, json: { error: 'no exam running' } }
      this.history.unshift({
        date: '2026-10-21 10:00',
        score: this.examResult.score,
        timeUsed: '1:30:00',
        questions: [...this.state.examQuestions],
      })
      this.stopExam()
      return { json: this.examResult }
    }
    if (key === 'POST /api/exam/abort') {
      this.stopExam()
      return { json: { ok: true } }
    }

    const m = path.match(/^\/api\/questions\/(\d+)(?:\/(lesson|solution|check|reset|flag))?$/)
    if (m) {
      const n = Number(m[1])
      const q = allQuestions.find((x) => x.n === n)
      if (!q) return { status: 404, json: { error: `question ${n} does not exist` } }
      const action = `${method} ${m[2] ?? ''}`
      if (action === 'GET ') {
        const step = learningPath.indexOf(n) + 1
        return {
          json: {
            n,
            title: q.title,
            domain: q.domain,
            weight: q.weight,
            context: q.context,
            step: step || null,
            steps: learningPath.length,
            markdown: questionMarkdown(n),
          },
        }
      }
      if (action === 'POST flag') {
        if (!inExam) return { status: 409, json: { error: 'flags are for exams: no exam is running' } }
        const on = !!(body as { flag?: boolean } | undefined)?.flag
        this.state.flags = this.state.flags.filter((x) => x !== n)
        if (on) this.state.flags.push(n)
        return { json: this.stateJson() }
      }
      if (action === 'GET lesson') return inExam ? blocked('lessons') : { json: { markdown: lessonMarkdown(n) } }
      if (action === 'GET solution') return inExam ? blocked('solutions') : { json: { markdown: solutionMarkdown(n) } }
      if (action === 'POST check') {
        if (inExam) return blocked('grading')
        const r = this.checks[n] ?? checkResult(n, [true, false, true], null)
        if (r.passed && !this.state.passed.includes(n)) this.state.passed.push(n)
        return { json: { ...r, next: this.stateJson().next } }
      }
      if (action === 'POST reset') return { json: { ok: true, log: '' } }
    }

    this.unhandled.push(key)
    return { status: 404, json: { error: 'unknown API endpoint' } }
  }
}

// Seeds localStorage before the first page load only, so reloads see what the app saved.
export async function seedStorage(page: Page, values: Record<string, unknown>) {
  await page.addInitScript((v) => {
    if (sessionStorage.getItem('pw-seeded')) return
    sessionStorage.setItem('pw-seeded', '1')
    for (const [k, val] of Object.entries(v)) localStorage.setItem(k, JSON.stringify(val))
  }, values)
}

// A promise the test resolves by hand, to hold a request "in flight".
export function gate() {
  let open!: () => void
  const opened = new Promise<void>((resolve) => (open = resolve))
  return { open, opened }
}

export const test = base.extend<{ api: MockApi }>({
  // Every mocked test gets the fake server, even if it never touches `api`.
  api: [
    async ({ page }, use) => {
      const api = new MockApi()
      await api.attach(page)
      await use(api)
      expect(api.unhandled, 'API calls the mock does not implement').toEqual([])
    },
    { auto: true },
  ],
})

export { expect }

// Locators shared by the specs.
export function ui(page: Page) {
  return {
    title: page.locator('.q-title'),
    qnum: page.locator('.q-num'),
    content: page.locator('.q-content'),
    modeBadge: page.locator('.mode-badge'),
    timer: page.locator('.timer'),
    toast: page.locator('.toast'),
    results: page.locator('.results'),
    drawer: page.getByRole('complementary', { name: 'Course' }),
    dialog: page.getByRole('dialog'),
    check: page.getByRole('button', { name: 'Check', exact: true }),
    reset: page.getByRole('button', { name: 'Reset', exact: true }),
    prev: page.getByRole('button', { name: '◀ Prev' }),
    next: page.getByRole('button', { name: /▶$/ }),
    tab: (name: 'Question' | 'Lesson' | 'Solution') => page.getByRole('tab', { name }),
    terminal: page.locator('.xterm-rows'),
    termDot: page.locator('.term-title .dot'),
  }
}
