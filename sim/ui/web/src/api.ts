// Typed client for the CKAD Lab API (see sim/ui/API.md).

export type Mode = 'learn' | 'exam'
export type DomainCode = 'D1' | 'D2' | 'D3' | 'D4' | 'D5'

export interface State {
  mode: Mode
  examStartedAt: number | null
  examSeconds: number
  examQuestions: number[]
  flags: number[] // exam questions flagged for review
  passed: number[]
  next: number | null
  total: number
}

export interface Domain {
  name: string
  short: string
  weight: number
}

export interface CourseQuestion {
  n: number
  title: string
  lesson: string
  domain: DomainCode
  weight: number // task weight: its share of an exam in points (~100 per exam)
  context: string // the kubectl context it is set up and graded in
  passed: boolean
}

export interface CourseSection {
  title: string
  questions: CourseQuestion[]
}

export interface Course {
  lesson0: { title: string }
  sections: CourseSection[]
  domains: Record<string, Domain>
  contexts: string[]
}

export interface Question {
  n: number
  title: string
  domain: DomainCode
  weight: number
  context: string
  step: number | null
  steps: number
  markdown: string
}

export interface Task {
  ok: boolean
  text: string
}

export interface CheckResult {
  n: number
  tasks: Task[]
  pass: number
  total: number
  passed: boolean
  next: number | null
}

export interface ResetResult {
  ok: boolean
  log: string
}

export interface ExamDomainResult {
  code: DomainCode
  name: string
  short: string
  weight: number
  pass: number
  total: number
  percent: number
}

export interface ExamQuestionResult {
  n: number
  title: string
  domain: DomainCode
  weight: number
  pass: number
  total: number
  tasks: Task[]
}

export interface ExamResult {
  score: number
  passedExam: boolean
  passMark: number
  timeUsed: number
  domains: ExamDomainResult[]
  questions: ExamQuestionResult[]
}

export interface HistoryEntry {
  date: string
  score: number
  timeUsed: string
  questions: number[]
}

export class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    res = await fetch(path, {
      ...init,
      headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
    })
  } catch {
    throw new ApiError(0, 'Cannot reach the CKAD Lab server. Is the simulator running?')
  }
  const text = await res.text()
  let body: unknown = undefined
  if (text) {
    try {
      body = JSON.parse(text)
    } catch {
      body = undefined
    }
  }
  if (!res.ok) {
    const msg =
      body && typeof body === 'object' && 'error' in body
        ? String((body as { error: unknown }).error)
        : `Request failed (${res.status})`
    throw new ApiError(res.status, msg)
  }
  return body as T
}

const post = <T>(path: string, data?: unknown) =>
  request<T>(path, { method: 'POST', body: data === undefined ? undefined : JSON.stringify(data) })

export const api = {
  state: () => request<State>('/api/state'),
  course: () => request<Course>('/api/course'),
  question: (n: number) => request<Question>(`/api/questions/${n}`),
  lesson: (n: number) => request<{ markdown: string }>(n === 0 ? '/api/lessons/0' : `/api/questions/${n}/lesson`),
  solution: (n: number) => request<{ markdown: string }>(`/api/questions/${n}/solution`),
  check: (n: number) => post<CheckResult>(`/api/questions/${n}/check`),
  reset: (n: number) => post<ResetResult>(`/api/questions/${n}/reset`),
  flag: (n: number, flag: boolean) => post<State>(`/api/questions/${n}/flag`, { flag }),
  examStart: (keep: boolean) => post<State>('/api/exam/start', { keep }),
  examEnd: () => post<ExamResult>('/api/exam/end'),
  examAbort: () => post<{ ok: boolean }>('/api/exam/abort'),
  examHistory: () => request<{ entries: HistoryEntry[] }>('/api/exam/history'),
}

export function terminalUrl(): string {
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  return `${proto}//${window.location.host}/api/terminal`
}

export function errorMessage(e: unknown): string {
  if (e instanceof Error) return e.message
  return String(e)
}
