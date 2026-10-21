// Tests against the running simulator (.\sim.ps1 up). Read-only on purpose: nothing here
// resets a question or starts an exam, so your answers and progress are safe. The one
// thing that can change is Check: grading a question you have fully solved records it as
// passed, exactly like pressing Check yourself.
import http from 'node:http'
import { expect, test } from '@playwright/test'
import type { Course, State } from '../../src/api'

let state: State | null = null
let base = ''

test.beforeAll(async ({}, info) => {
  base = info.project.use.baseURL!
  try {
    state = (await (await fetch(`${base}/api/state`)).json()) as State
  } catch {
    state = null
  }
})

test.beforeEach(() => {
  test.skip(!state, `the simulator is not running (nothing answers on ${base}); start it with .\\sim.ps1 up`)
})

const learningOnly = () => test.skip(state?.mode === 'exam', 'an exam is running: lessons, solutions and grading are locked')

// Raw HTTP, so the test controls the Origin and Host headers a browser would set.
function rawStatus(path: string, opts: { method?: string; headers?: Record<string, string> } = {}): Promise<number> {
  return new Promise((resolve, reject) => {
    const req = http.request(`${base}${path}`, { method: opts.method ?? 'GET', headers: opts.headers })
    req.on('upgrade', (res, socket) => {
      socket.destroy() // closing the socket ends the shell the server just started
      resolve(res.statusCode ?? 101)
    })
    req.on('response', (res) => {
      res.resume()
      resolve(res.statusCode ?? 0)
    })
    req.on('error', reject)
    req.end()
  })
}

const upgrade = (origin: string) => ({
  Connection: 'Upgrade',
  Upgrade: 'websocket',
  'Sec-WebSocket-Version': '13',
  'Sec-WebSocket-Key': 'dGhlIHNhbXBsZSBub25jZQ==',
  Origin: origin,
})

test.describe('API', () => {
  test('state and course agree', async ({ request }) => {
    const s = (await (await request.get('/api/state')).json()) as State
    const c = (await (await request.get('/api/course')).json()) as Course
    const ns = c.sections.flatMap((sec) => sec.questions.map((q) => q.n))

    expect(new Set(ns).size, 'a question appears in two sections').toBe(ns.length)
    expect(ns.length).toBe(s.total)
    expect(Object.keys(c.domains).sort()).toEqual(['D1', 'D2', 'D3', 'D4', 'D5'])
    expect(Object.values(c.domains).reduce((sum, d) => sum + d.weight, 0)).toBe(100)
    for (const sec of c.sections) {
      for (const q of sec.questions) {
        expect(c.domains[q.domain], `Q${q.n} has an unknown domain ${q.domain}`).toBeTruthy()
        expect(q.title, `Q${q.n} has no title`).not.toBe('')
        expect(q.lesson, `Q${q.n} has no lesson title`).not.toBe('')
      }
    }
    for (const n of s.passed) expect(ns).toContain(n)
    if (s.next !== null) expect(ns).toContain(s.next)
    expect(['learn', 'exam']).toContain(s.mode)
  })

  test('every question has its text, lesson and solution', async ({ request }) => {
    learningOnly()
    const c = (await (await request.get('/api/course')).json()) as Course
    const ns = c.sections.flatMap((sec) => sec.questions.map((q) => q.n))
    const lesson0 = await request.get('/api/lessons/0')
    expect(lesson0.status()).toBe(200)

    const problems: string[] = []
    await Promise.all(
      ns.flatMap((n) =>
        ['', '/lesson', '/solution'].map(async (part) => {
          const res = await request.get(`/api/questions/${n}${part}`)
          const body = await res.json()
          if (res.status() !== 200) problems.push(`Q${n}${part}: ${res.status()} ${body.error}`)
          else if (!String(body.markdown).trim().startsWith('#')) problems.push(`Q${n}${part}: no markdown heading`)
        }),
      ),
    )
    expect(problems).toEqual([])
  })

  test('errors are JSON with the right status', async ({ request }) => {
    const cases: [string, number][] = [
      ['/api/nope', 404],
      ['/api/questions/abc', 400],
      ['/api/questions/9999', 404],
    ]
    for (const [path, status] of cases) {
      const res = await request.get(path)
      expect(res.status(), path).toBe(status)
      expect((await res.json()).error, path).toBeTruthy()
    }
  })
})

test.describe('security', () => {
  test('refuses writes from other websites', async () => {
    // A bad question number: harmless even if the guard were missing (that gives 400).
    const headers = { Origin: 'http://evil.test' }
    expect(await rawStatus('/api/questions/abc/check', { method: 'POST', headers })).toBe(403)
  })

  test('refuses foreign Host headers (DNS rebinding)', async () => {
    expect(await rawStatus('/api/state', { headers: { Host: 'evil.test:8090' } })).toBe(403)
    expect(await rawStatus('/api/state', { headers: { Host: '127.0.0.1:8090' } })).toBe(200)
  })

  test('only the app itself can open a terminal', async () => {
    expect(await rawStatus('/api/terminal', { headers: upgrade('http://evil.test') })).toBe(403)
    expect(await rawStatus('/api/terminal', { headers: upgrade(base) })).toBe(101)
  })
})

test.describe('UI', () => {
  test('loads the course and the current question', async ({ page }) => {
    await page.goto('/')
    await expect(page).toHaveTitle('CKAD Lab')
    await expect(page.locator('.q-num')).toHaveText(/^(Q\d+|Lesson 0)$/)
    await expect(page.locator('.q-content .markdown')).not.toBeEmpty()
    await expect(page.locator('.banner.error')).toHaveCount(0)

    await page.getByRole('button', { name: state?.mode === 'exam' ? 'Questions' : 'Course', exact: true }).click()
    const items = page.locator('.drawer.open .drawer-item:not(.lesson0)')
    await expect(items).toHaveCount(state?.mode === 'exam' ? state.examQuestions.length : state!.total)
  })

  test('names and paths in the question copy with one click', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    await page.goto('/')
    const value = page.locator('.q-content code.copyable').first()
    await expect(value).toBeVisible()
    const text = await value.textContent()
    await value.click()
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(text)
  })

  test('lesson and solution tabs load', async ({ page }) => {
    learningOnly()
    await page.goto('/')
    await expect(page.locator('.q-num')).toHaveText(/^Q\d+$/)
    await page.getByRole('tab', { name: 'Lesson' }).click()
    await expect(page.locator('.markdown.lesson h1')).toBeVisible()
    await page.getByRole('tab', { name: 'Solution' }).click()
    await page.getByRole('button', { name: 'Show the solution' }).click()
    await expect(page.locator('.q-content .markdown h1')).toBeVisible()
    await expect(page.locator('.q-content .error-box')).toHaveCount(0)
  })

  test('the terminal runs commands against the cluster', async ({ page }) => {
    await page.goto('/')
    const term = page.locator('.xterm-rows')
    await expect(page.locator('.term-title .dot')).toHaveClass(/open/)
    await expect(term).toContainText('candidate@ckad', { timeout: 15_000 })
    await page.locator('.term-body').click()

    await page.keyboard.type('echo "pw-$((6*7))"')
    await page.keyboard.press('Enter')
    await expect(term).toContainText('pw-42')

    await page.keyboard.type('kubectl get ns kube-system -o name')
    await page.keyboard.press('Enter')
    await expect(term).toContainText('namespace/kube-system', { timeout: 30_000 })
  })

  test('Check grades the current question', async ({ page }) => {
    learningOnly()
    test.setTimeout(150_000)
    await page.goto('/')
    await expect(page.locator('.q-num')).toHaveText(/^Q\d+$/)
    await page.getByRole('button', { name: 'Check', exact: true }).click()
    await expect(page.locator('.results')).toContainText(/\d+\/\d+ tasks/, { timeout: 120_000 })
    await expect(page.locator('.results .task')).not.toHaveCount(0)
  })
})
