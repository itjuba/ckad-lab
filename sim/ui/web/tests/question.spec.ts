import type { Page } from '@playwright/test'
import { checkResult } from './fixtures/data'
import { expect, gate, test, ui } from './fixtures/mock-api'

test.describe('lesson and solution tabs', () => {
  test('the lesson keeps its terminal layout', async ({ page }) => {
    await page.goto('/')
    await ui(page).tab('Lesson').click()
    await expect(ui(page).tab('Lesson')).toHaveAttribute('aria-selected', 'true')

    const lesson = page.locator('.markdown.lesson')
    await expect(lesson.getByRole('heading', { level: 1 })).toHaveText('Lesson 1: the theory')
    // Aligned columns become a preformatted block with their spacing intact...
    const table = lesson.locator('pre').filter({ hasText: 'READY' })
    expect(await table.innerText()).toContain('pod-a    1/1     Running')
    // ...and the 90-dash separator becomes a rule, not a heading underline.
    await expect(lesson.locator('hr')).toHaveCount(1)
  })

  test('the solution stays hidden until asked for', async ({ page, api }) => {
    await page.goto('/')
    await ui(page).tab('Solution').click()
    await expect(page.getByText('Try the question on your own first.')).toBeVisible()
    expect(api.callsTo('GET /api/questions/1/solution')).toHaveLength(0)

    await page.getByRole('button', { name: 'Show the solution' }).click()
    await expect(ui(page).content).toContainText('kubectl -n q1 create deployment web --image=nginx')
    expect(api.callsTo('GET /api/questions/1/solution')).toHaveLength(1)

    // Revealed solutions stay revealed when you come back to the tab.
    await ui(page).tab('Question').click()
    await ui(page).tab('Solution').click()
    await expect(ui(page).content).toContainText('create deployment web')
  })

  test('shows the server error when a lesson is missing', async ({ page, api }) => {
    api.on('GET /api/questions/1/lesson', () => ({ status: 404, json: { error: 'no lessons for this question yet' } }))
    await page.goto('/')
    await ui(page).tab('Lesson').click()
    await expect(page.locator('.error-box')).toHaveText('no lessons for this question yet')
  })

  test('code blocks have a working copy button', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    await page.goto('/')
    const block = ui(page).content.locator('.codeblock')
    await block.hover()
    await block.getByRole('button', { name: 'copy' }).click()
    await expect(block.getByRole('button', { name: 'copied' })).toBeVisible()
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe('kubectl -n q1 get pods')
  })
})

test.describe('one-click copy, like the exam', () => {
  test.beforeEach(({ context }) => context.grantPermissions(['clipboard-read', 'clipboard-write']))
  const clipboard = (page: Page) => page.evaluate(() => navigator.clipboard.readText())

  test('a click on a name or path in the question copies it', async ({ page }) => {
    await page.goto('/')
    const path = ui(page).content.getByRole('button', { name: '/opt/course/1/answer' })
    await expect(path).toHaveAttribute('title', 'Click to copy')
    await path.click()
    await expect(path).toHaveClass(/copied/)
    expect(await clipboard(page)).toBe('/opt/course/1/answer')
    await expect(path).not.toHaveClass(/copied/)
  })

  test('works from the keyboard', async ({ page }) => {
    await page.goto('/')
    await ui(page).content.getByRole('button', { name: 'q1', exact: true }).focus()
    await page.keyboard.press('Enter')
    expect(await clipboard(page)).toBe('q1')
  })

  test('copy in the question, Ctrl+Shift+V in the terminal', async ({ page, api }) => {
    await page.goto('/')
    await expect(ui(page).termDot).toHaveClass(/open/)
    await ui(page).content.getByRole('button', { name: '/opt/course/1/answer' }).click()
    await page.locator('.term-body').click()
    await page.keyboard.type('cat ')
    await page.keyboard.press('Control+Shift+V')
    await expect.poll(() => api.terminal.input).toBe('cat /opt/course/1/answer')
  })

  test('also works during an exam', async ({ page, api }) => {
    api.startExam(60)
    await page.goto('/')
    await ui(page).content.getByRole('button', { name: '/opt/course/4/answer' }).click()
    expect(await clipboard(page)).toBe('/opt/course/4/answer')
  })

  test('only inline values in questions are click-to-copy', async ({ page }) => {
    await page.goto('/')
    await expect(ui(page).content.locator('.markdown code.copyable')).toHaveCount(2)
    // Code blocks keep their copy button instead.
    await expect(ui(page).content.locator('pre code.copyable')).toHaveCount(0)
    await ui(page).tab('Solution').click()
    await page.getByRole('button', { name: 'Show the solution' }).click()
    await expect(ui(page).content).toContainText('create deployment web')
    await expect(ui(page).content.locator('.markdown code.copyable')).toHaveCount(0)
  })
})

test.describe('Check', () => {
  test('lists every task with its result', async ({ page, api }) => {
    const g = gate()
    api.on('POST /api/questions/1/check', async () => {
      await g.opened
      return { json: checkResult(1, [true, false, true], 1) }
    })
    await page.goto('/')
    const u = ui(page)
    await u.check.click()
    await expect(page.getByRole('button', { name: 'Checking…' })).toBeDisabled()
    await expect(u.reset).toBeDisabled()
    g.open()

    await expect(u.results).toContainText('2/3 tasks')
    await expect(u.results.locator('.task.ok')).toHaveCount(2)
    await expect(u.results.locator('.task.ko')).toHaveText('✘task 2 of Q1')
    await expect(u.results.getByText('Passed!')).toHaveCount(0)

    await u.results.getByRole('button', { name: 'Hide results' }).click()
    await expect(u.results).toHaveCount(0)
  })

  test('full marks: passed banner, toast, progress and a link to the next question', async ({ page, api }) => {
    api.checks[1] = checkResult(1, [true, true], null)
    await page.goto('/')
    const u = ui(page)
    await expect(page.locator('.progress')).toContainText('0/5 passed')

    await u.check.click()
    await expect(u.results.locator('.passed-banner')).toContainText('Passed!')
    await expect(u.toast).toHaveText('Q1 passed!')
    await expect(page.locator('.progress')).toContainText('1/5 passed')

    await u.results.getByRole('button', { name: 'Next: Q5' }).click()
    await expect(u.qnum).toHaveText('Q5')
  })

  test('Ctrl+Enter grades the question, even from the terminal', async ({ page, api }) => {
    await page.goto('/')
    await expect(ui(page).termDot).toHaveClass(/open/)
    await page.locator('.term-body').click()
    await page.keyboard.press('Control+Enter')
    await expect(ui(page).results).toContainText('2/3 tasks')
    expect(api.callsTo('POST /api/questions/1/check')).toHaveLength(1)
    // The shell never saw the Enter.
    expect(api.terminal.input).not.toContain('\r')
  })

  test('shows grading errors', async ({ page, api }) => {
    api.on('POST /api/questions/1/check', () => ({ status: 500, json: { error: 'check for question 1 timed out' } }))
    await page.goto('/')
    await ui(page).check.click()
    await expect(ui(page).results.locator('.error-box')).toHaveText('check for question 1 timed out')
  })

  test('results belong to their question', async ({ page }) => {
    await page.goto('/')
    const u = ui(page)
    await u.check.click()
    await expect(u.results).toContainText('2/3 tasks')
    await u.next.click()
    await expect(u.qnum).toHaveText('Q5')
    await expect(u.results).toHaveCount(0)
    await u.prev.click()
    await expect(u.results).toContainText('2/3 tasks')
  })
})

test.describe('Reset', () => {
  test('asks first, and Cancel changes nothing', async ({ page, api }) => {
    await page.goto('/')
    await ui(page).reset.click()
    await expect(ui(page).dialog).toContainText('deletes your work')
    await page.getByRole('button', { name: 'Cancel' }).click()
    await expect(ui(page).dialog).toHaveCount(0)
    expect(api.callsTo('POST /api/questions/1/reset')).toHaveLength(0)
  })

  test('resets the question and says so', async ({ page, api }) => {
    const g = gate()
    api.on('POST /api/questions/1/reset', async () => {
      await g.opened
      return { json: { ok: true, log: '' } }
    })
    await page.goto('/')
    const u = ui(page)
    await u.reset.click()
    await u.dialog.getByRole('button', { name: 'Reset question' }).click()
    await expect(page.getByRole('button', { name: 'Resetting…' })).toBeDisabled()
    await expect(u.check).toBeDisabled()
    g.open()
    await expect(u.results.locator('.notice.ok')).toHaveText('Q1 is back to its starting state.')
    await expect(u.check).toBeEnabled()
  })

  test('shows the setup log when the reset fails', async ({ page, api }) => {
    api.on('POST /api/questions/1/reset', () => ({
      json: { ok: false, log: 'error: namespaces "q1" is forbidden' },
    }))
    await page.goto('/')
    await ui(page).reset.click()
    await ui(page).dialog.getByRole('button', { name: 'Reset question' }).click()
    const box = ui(page).results.locator('.error-box')
    await expect(box).toContainText('Reset failed.')
    await expect(box.locator('.log')).toHaveText('error: namespaces "q1" is forbidden')
  })
})
