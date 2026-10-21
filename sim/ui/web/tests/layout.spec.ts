import { expect, test, ui } from './fixtures/mock-api'

test.describe('server down', () => {
  test('says so, and Retry recovers once it is back', async ({ page, api }) => {
    api.offline = true
    await page.goto('/')
    const banner = page.locator('.banner.error')
    await expect(banner).toContainText('Cannot reach the CKAD Lab server. Is the simulator running?')
    await expect(page.getByText('Waiting for the server…')).toBeVisible()

    api.offline = false
    await banner.getByRole('button', { name: 'Retry' }).click()
    await expect(banner).toHaveCount(0)
    await expect(ui(page).qnum).toHaveText('Q1')
    await expect(ui(page).title).toHaveText('Namespace and pod inventory')
  })

  test('recovers on its own when the server comes back', async ({ page, api }) => {
    await page.clock.install()
    api.offline = true
    await page.goto('/')
    await expect(page.locator('.banner.error')).toBeVisible()
    api.offline = false
    await page.clock.fastForward('00:11')
    await expect(page.locator('.banner.error')).toHaveCount(0)
    await expect(ui(page).title).toHaveText('Namespace and pod inventory')
  })
})

test.describe('split view', () => {
  test('the splitter resizes the panes and the width is remembered', async ({ page }) => {
    await page.goto('/')
    const left = page.locator('.pane.left')
    await expect(ui(page).title).toBeVisible()
    const start = (await left.boundingBox())!.width
    expect(start).toBeCloseTo(1400 * 0.42, -1)

    const bar = (await page.locator('.splitter').boundingBox())!
    await page.mouse.move(bar.x + 3, bar.y + 200)
    await page.mouse.down()
    await page.mouse.move(700, bar.y + 200, { steps: 5 })
    await page.mouse.up()
    await expect.poll(async () => (await left.boundingBox())!.width).toBeCloseTo(700, -1)

    await page.reload()
    await expect(ui(page).title).toBeVisible()
    expect((await left.boundingBox())!.width).toBeCloseTo(700, -1)
  })

  test('the splitter stops at 25% and 70%', async ({ page }) => {
    await page.goto('/')
    const left = page.locator('.pane.left')
    const bar = (await page.locator('.splitter').boundingBox())!
    await page.mouse.move(bar.x + 3, bar.y + 200)
    await page.mouse.down()
    await page.mouse.move(10, bar.y + 200, { steps: 5 })
    await expect.poll(async () => (await left.boundingBox())!.width).toBeCloseTo(1400 * 0.25, -1)
    await page.mouse.move(1390, bar.y + 200, { steps: 5 })
    await expect.poll(async () => (await left.boundingBox())!.width).toBeCloseTo(1400 * 0.7, -1)
    await page.mouse.up()
  })

  test('small screens stack the question above the terminal', async ({ page }) => {
    await page.setViewportSize({ width: 800, height: 900 })
    await page.goto('/')
    await expect(ui(page).title).toBeVisible()
    await expect(page.locator('.splitter')).toBeHidden()
    const q = (await page.locator('.pane.left').boundingBox())!
    const t = (await page.locator('.pane.right').boundingBox())!
    expect(q.width).toBe(800)
    expect(t.y).toBeGreaterThanOrEqual(q.y + q.height - 1)
    await expect(ui(page).termDot).toHaveClass(/open/)
  })
})
