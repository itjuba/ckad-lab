// Small, fixed course used by the mocked tests. The learning path (1, 5, 3, 2, 4) is
// deliberately not in numeric order, like the real one.
import type { CheckResult, Course, CourseSection, Domain, ExamResult } from '../../src/api'

export const domains: Record<string, Domain> = {
  D1: { name: 'Application Design and Build', short: 'Design & Build', weight: 20 },
  D2: { name: 'Application Deployment', short: 'Deployment', weight: 20 },
  D3: { name: 'Application Observability and Maintenance', short: 'Observability', weight: 15 },
  D4: { name: 'Application Environment, Configuration and Security', short: 'Config & Security', weight: 25 },
  D5: { name: 'Services and Networking', short: 'Networking', weight: 20 },
}

type Q = CourseSection['questions'][number]

export const contexts = ['ckad-c1', 'ckad-c2']

// Weights: the exam [4, 1, 3] adds up to 12, so Q4 is 50%, Q1 17% and Q3 33% of it.
const q = (n: number, title: string, lesson: string, domain: Q['domain'], weight: number, context: string): Omit<Q, 'passed'> => ({
  n,
  title,
  lesson,
  domain,
  weight,
  context,
})

export const sections: { title: string; questions: Omit<Q, 'passed'>[] }[] = [
  {
    title: 'Pods & kubectl basics',
    questions: [
      q(1, 'Namespace and pod inventory', 'Namespaces, labels and selectors', 'D3', 2, 'ckad-c1'),
      q(5, 'Multi-container pod', 'Sidecars and shared volumes', 'D1', 5, 'ckad-c2'),
    ],
  },
  {
    title: 'Configuration',
    questions: [q(3, 'ConfigMap and Secret env', 'ConfigMaps, Secrets and env vars', 'D4', 4, 'ckad-c1')],
  },
  {
    title: 'Deployments & Services',
    questions: [
      q(2, 'Rolling update and rollback', 'Deployments and rollouts', 'D2', 5, 'ckad-c2'),
      q(4, 'Expose with a Service', 'Services and endpoints', 'D5', 6, 'ckad-c2'),
    ],
  },
]

export const learningPath = sections.flatMap((s) => s.questions.map((x) => x.n))
export const allQuestions = sections.flatMap((s) => s.questions)

export function course(passed: number[]): Course {
  return {
    lesson0: { title: 'Kubernetes & kubectl fundamentals' },
    sections: sections.map((s) => ({
      title: s.title,
      questions: s.questions.map((x) => ({ ...x, passed: passed.includes(x.n) })),
    })),
    domains,
    contexts,
  }
}

export function questionMarkdown(n: number): string {
  const title = allQuestions.find((x) => x.n === n)?.title ?? `Question ${n}`
  return `# ${title}

Work in namespace \`q${n}\`.

1. Create the resources described below.
2. Write the answer to \`/opt/course/${n}/answer\`.

\`\`\`bash
kubectl -n q${n} get pods
\`\`\`
`
}

// Lessons are written for a terminal: the aligned table must survive as a <pre> block.
export function lessonMarkdown(n: number): string {
  return `# Lesson ${n}: the theory

A pod is the smallest unit you deploy.

    NAME     READY   STATUS
    pod-a    1/1     Running

------------------------------------------------------------------------------------------

Key idea: labels select objects.
`
}

export const lesson0Markdown = `# Lesson 0: Kubernetes & kubectl fundamentals

Everything in Kubernetes is an object with a kind, a name and a namespace.
`

export function solutionMarkdown(n: number): string {
  return `# Solution ${n}

\`\`\`bash
kubectl -n q${n} create deployment web --image=nginx
\`\`\`
`
}

export function checkResult(n: number, oks: boolean[], next: number | null): CheckResult {
  const pass = oks.filter(Boolean).length
  return {
    n,
    tasks: oks.map((ok, i) => ({ ok, text: `task ${i + 1} of Q${n}` })),
    pass,
    total: oks.length,
    passed: pass === oks.length,
    next,
  }
}

export const examQuestions = [4, 1, 3]

export const examResult: ExamResult = {
  score: 71,
  passedExam: true,
  passMark: 66,
  timeUsed: 5400,
  domains: [
    { code: 'D3', ...domains.D3, pass: 3, total: 3, percent: 100 },
    { code: 'D4', ...domains.D4, pass: 1, total: 3, percent: 33 },
    { code: 'D5', ...domains.D5, pass: 2, total: 2, percent: 100 },
  ],
  questions: [
    {
      n: 4,
      title: 'Expose with a Service',
      domain: 'D5',
      weight: 6,
      pass: 2,
      total: 2,
      tasks: [
        { ok: true, text: 'service web exists' },
        { ok: true, text: 'service selects the web pods' },
      ],
    },
    {
      n: 1,
      title: 'Namespace and pod inventory',
      domain: 'D3',
      weight: 2,
      pass: 3,
      total: 3,
      tasks: [{ ok: true, text: 'team-namespaces is correct' }],
    },
    {
      n: 3,
      title: 'ConfigMap and Secret env',
      domain: 'D4',
      weight: 4,
      pass: 1,
      total: 3,
      tasks: [
        { ok: true, text: 'configmap app-config exists' },
        { ok: false, text: 'pod reads DB_PASSWORD from the secret' },
      ],
    },
  ],
}
