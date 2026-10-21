import { expect, gate, seedStorage, test, ui } from './fixtures/mock-api'

test.describe('starting an exam', () => {
  test('locks lessons, solutions and grading, and starts the timer', async ({ page, api }) => {
    const g = gate()
    api.on('POST /api/exam/start', async () => {
      await g.opened
      api.startExam(0)
      return { json: api.stateJson() }
    })
    await page.goto('/')
    const u = ui(page)
    await expect(u.modeBadge).toHaveText('Learning')

    await page.getByRole('button', { name: 'Start exam' }).click()
    await expect(u.dialog).toContainText('18 random questions')
    await u.dialog.getByRole('button', { name: 'Start the 2-hour exam' }).click()
    await expect(u.dialog.getByRole('button', { name: 'Setting up the exam…' })).toBeDisabled()
    // Busy: Escape must not close the dialog while questions are being reset.
    await page.keyboard.press('Escape')
    await expect(u.dialog).toBeVisible()
    g.open()

    await expect(u.dialog).toHaveCount(0)
    await expect(u.toast).toHaveText('Mock exam started. Good luck!')
    await expect(u.modeBadge).toHaveText('Exam')
    await expect(u.timer).toHaveText(/^(2:00:00|1:59:\d\d)$/)
    await expect(u.qnum).toHaveText('Q4')
    await expect(page.getByText('Exam question 1 of 3')).toBeVisible()
    await expect(page.getByRole('tab')).toHaveText(['Question'])
    await expect(u.check).toBeDisabled()
    await expect(u.prev).toBeDisabled()
    await expect(page.getByRole('button', { name: 'Start exam' })).toHaveCount(0)
    await expect(page.locator('.progress')).toHaveCount(0)
    expect(api.callsTo('POST /api/exam/start')[0].body).toEqual({ keep: false })
  })

  test('can keep the current state of the questions', async ({ page, api }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Start exam' }).click()
    await ui(page).dialog.getByRole('checkbox').check()
    await ui(page).dialog.getByRole('button', { name: 'Start the 2-hour exam' }).click()
    await expect(ui(page).modeBadge).toHaveText('Exam')
    expect(api.callsTo('POST /api/exam/start')[0].body).toEqual({ keep: true })
  })

  test('shows setup errors and stays in learning mode', async ({ page, api }) => {
    api.on('POST /api/exam/start', () => ({
      status: 500,
      json: { error: 'setup failed for question(s) 4; see /tmp/ckad-logs' },
    }))
    await page.goto('/')
    await page.getByRole('button', { name: 'Start exam' }).click()
    await ui(page).dialog.getByRole('button', { name: 'Start the 2-hour exam' }).click()
    await expect(ui(page).dialog.locator('.error-box')).toHaveText('setup failed for question(s) 4; see /tmp/ckad-logs')
    await expect(ui(page).modeBadge).toHaveText('Learning')
  })

  test('follows an exam started from the CLI', async ({ page, api }) => {
    await page.clock.install()
    await page.goto('/')
    await expect(ui(page).modeBadge).toHaveText('Learning')
    api.startExam(0)
    await page.clock.fastForward('00:11')
    await expect(ui(page).modeBadge).toHaveText('Exam')
    await expect(ui(page).qnum).toHaveText('Q4')
  })
})

test.describe('during an exam', () => {
  test.beforeEach(({ api }) => api.startExam(120))

  test('the drawer lists only the exam questions, in exam order', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Questions' }).click()
    const drawer = ui(page).drawer
    await expect(drawer.getByRole('heading', { level: 2 })).toHaveText('Exam questions')
    await expect(drawer.getByRole('button', { name: /^\d\./ })).toHaveText([
      /1\.Q4 Expose with a Service/,
      /2\.Q1 Namespace and pod inventory/,
      /3\.Q3 ConfigMap and Secret env/,
    ])
    await drawer.getByRole('button', { name: /Q3 ConfigMap/ }).click()
    await expect(ui(page).qnum).toHaveText('Q3')
    await expect(page.getByText('Exam question 3 of 3')).toBeVisible()
    await expect(ui(page).next).toBeDisabled()
  })

  test('Lesson 0 is not reachable', async ({ page }) => {
    await seedStorage(page, { 'ckad.lastView': { kind: 'lesson0' } })
    await page.goto('/')
    await expect(ui(page).qnum).toHaveText('Q4')
    await expect(page.locator('.banner.hint')).toHaveCount(0)
  })

  test('the timer turns red in the last 10 minutes', async ({ page, api }) => {
    api.startExam(7200 - 300)
    await page.goto('/')
    await expect(ui(page).timer).toHaveClass(/red/)
    await expect(ui(page).timer).toHaveText(/^0:0[45]:\d\d$/)
  })

  test('the timer says when time is up', async ({ page, api }) => {
    api.startExam(7300)
    await page.goto('/')
    await expect(ui(page).timer).toHaveText('Time is up')
    await expect(ui(page).timer).toHaveClass(/over/)
  })
})

test.describe('ending an exam', () => {
  test.beforeEach(({ api }) => api.startExam(5400))

  test('grades it and shows the results by domain and question', async ({ page }) => {
    await page.goto('/')
    const u = ui(page)
    await page.getByRole('button', { name: 'End exam' }).click()
    await u.dialog.getByRole('button', { name: 'End and grade' }).click()

    const results = page.getByRole('dialog', { name: 'Mock exam results' })
    await expect(results.locator('.score')).toHaveText('71%')
    await expect(results.locator('.verdict')).toHaveText('PASS')
    await expect(results).toContainText('Pass mark 66% · time used 1:30:00')
    await expect(results.locator('tbody tr')).toHaveCount(3)
    await expect(results.locator('tbody tr').nth(1)).toContainText('Config & Security25%1/333%')

    const q3 = results.getByRole('button', { name: /Q3 ConfigMap and Secret env/ })
    await expect(q3).toContainText('1/3')
    await q3.click()
    await expect(results.locator('.tasks.nested .task.ko')).toHaveText('✘pod reads DB_PASSWORD from the secret')

    await results.getByRole('button', { name: 'Back to learning mode' }).click()
    await expect(results).toHaveCount(0)
    await expect(u.modeBadge).toHaveText('Learning')
    await expect(page.getByRole('tab')).toHaveText(['Question', 'Lesson', 'Solution'])
  })

  test('a failed exam says NOT YET', async ({ page, api }) => {
    api.examResult = { ...api.examResult, score: 40, passedExam: false }
    await page.goto('/')
    await page.getByRole('button', { name: 'End exam' }).click()
    await ui(page).dialog.getByRole('button', { name: 'End and grade' }).click()
    await expect(page.locator('.verdict')).toHaveText('NOT YET')
    await expect(page.locator('.score')).toHaveClass(/fail/)
  })

  test('shows grading errors in the confirm dialog', async ({ page, api }) => {
    api.on('POST /api/exam/end', () => ({ status: 409, json: { error: 'the exam is already being graded' } }))
    await page.goto('/')
    await page.getByRole('button', { name: 'End exam' }).click()
    await ui(page).dialog.getByRole('button', { name: 'End and grade' }).click()
    await expect(ui(page).dialog.locator('.error-box')).toHaveText('the exam is already being graded')
  })

  test('Abort stops without grading', async ({ page, api }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Abort' }).click()
    await ui(page).dialog.getByRole('button', { name: 'Abort exam' }).click()
    await expect(ui(page).toast).toHaveText('Exam stopped without grading.')
    await expect(ui(page).modeBadge).toHaveText('Learning')
    expect(api.callsTo('POST /api/exam/end')).toHaveLength(0)
  })
})

test.describe('history', () => {
  test('is empty at first', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'History' }).click()
    await expect(ui(page).dialog).toContainText('No mock exams taken yet.')
  })

  test('lists past exams, newest first', async ({ page, api }) => {
    api.history = [
      { date: '2026-10-21 09:00', score: 71, timeUsed: '1:30:00', questions: [4, 1, 3] },
      { date: '2026-10-20 14:02', score: 52, timeUsed: '2:00:00', questions: [2, 5] },
    ]
    await page.goto('/')
    await page.getByRole('button', { name: 'History' }).click()
    const rows = ui(page).dialog.locator('tbody tr')
    await expect(rows).toHaveCount(2)
    await expect(rows.first()).toContainText('2026-10-21 09:00')
    await expect(rows.first().locator('.good')).toHaveText('71%')
    await expect(rows.nth(1).locator('.bad')).toHaveText('52%')
  })
})
