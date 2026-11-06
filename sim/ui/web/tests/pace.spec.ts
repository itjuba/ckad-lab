// Practice pace: a stopwatch per question against a target time from its weight (72 s per
// weight point, the exam's pace), and the best time once passed. Exams keep one clock.
import { checkResult } from './fixtures/data'
import { expect, test, ui } from './fixtures/mock-api'

const stopwatch = (page: import('@playwright/test').Page) => page.locator('.q-meta .stopwatch')

test.describe('practice pace', () => {
  test('opening a question starts its stopwatch against the target time', async ({ page, api }) => {
    await page.clock.install()
    await page.goto('/')
    await expect(ui(page).qnum).toHaveText('Q1')
    await expect(page.locator('.pace')).toContainText('/ target 2:24')
    await expect(stopwatch(page)).toHaveText(/^⏱ 0:0\d$/)
    expect(api.callsTo('POST /api/questions/1/timer')[0].body).toEqual({ restart: false })

    // Over the target: amber; over twice the target: red.
    await page.clock.fastForward('02:30')
    await expect(stopwatch(page)).toHaveClass(/over/)
    await expect(stopwatch(page)).not.toHaveClass(/way-over/)
    await page.clock.fastForward('02:30')
    await expect(stopwatch(page)).toHaveClass(/way-over/)
  })

  test('the stopwatch can be restarted', async ({ page, api }) => {
    api.state.timers = { '1': Math.floor(Date.now() / 1000) - 600 }
    await page.goto('/')
    await expect(stopwatch(page)).toHaveText(/^⏱ 10:0\d$/)
    await page.getByRole('button', { name: 'Restart the timer' }).click()
    await expect(stopwatch(page)).toHaveText(/^⏱ 0:0\d$/)
    expect(api.callsTo('POST /api/questions/1/timer').at(-1)!.body).toEqual({ restart: true })
  })

  test('a full pass shows the time, and the course keeps the best one', async ({ page, api }) => {
    api.state.timers = { '1': Math.floor(Date.now() / 1000) - 100 }
    api.checks[1] = checkResult(1, [true, true], null)
    await page.goto('/')
    await ui(page).check.click()
    await expect(ui(page).results.locator('.passed-banner')).toContainText(/in 1:4\d \(target 2:24\)/)

    // The stopwatch stops; the header shows the best time instead.
    await expect(page.locator('.q-meta .pace')).toContainText(/best 1:4\d\/ target 2:24/)
    await page.getByRole('button', { name: 'Course', exact: true }).click()
    await expect(ui(page).drawer.getByRole('button', { name: /Q1 Namespace/ })).toContainText(/best 1:4\d \/ 2:24/)
  })

  test('looking at a passed question does not start a new attempt; a reset does', async ({ page, api }) => {
    api.state.passed = [1]
    api.state.times = { '1': 130 }
    await page.goto('/?') // first visit opens Q5 (the next one): go back to Q1
    await ui(page).prev.click()
    await expect(ui(page).qnum).toHaveText('Q1')
    await expect(page.locator('.q-meta .pace')).toContainText('best 2:10/ target 2:24')
    expect(api.state.timers!['1']).toBeUndefined()

    await ui(page).reset.click()
    await ui(page).dialog.getByRole('button', { name: 'Reset question' }).click()
    await expect(stopwatch(page)).toHaveText(/^⏱ 0:0\d$/)
  })

  test('exams have one clock: no per-question stopwatch', async ({ page, api }) => {
    api.startExam(60)
    await page.goto('/')
    await expect(ui(page).qnum).toHaveText('Q4')
    await expect(page.locator('.pace')).toHaveCount(0)
    await expect(page.locator('.q-meta').getByText(/Target time/)).toHaveCount(0)
    expect(api.calls.filter((c) => c.path.endsWith('/timer'))).toHaveLength(0)
  })
})
