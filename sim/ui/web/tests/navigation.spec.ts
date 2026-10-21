import { expect, seedStorage, test, ui } from './fixtures/mock-api'

test.describe('first visit', () => {
  test('opens the next question of the learning path', async ({ page, api }) => {
    api.state.passed = [1]
    await page.goto('/')
    const u = ui(page)
    await expect(u.qnum).toHaveText('Q5')
    await expect(u.title).toHaveText('Multi-container pod')
    await expect(page.getByText('Step 2 of 5')).toBeVisible()
    await expect(page.locator('.chip')).toHaveText('Design & Build · 20%')
    await expect(u.content).toContainText('Work in namespace q5.')
  })

  test('shows the Lesson 0 hint to new users, and remembers when it is dismissed', async ({ page }) => {
    await page.goto('/')
    const hint = page.locator('.banner.hint')
    await expect(hint).toContainText('New here?')
    await hint.getByRole('button', { name: 'Open Lesson 0' }).click()
    await expect(ui(page).qnum).toHaveText('Lesson 0')
    await expect(ui(page).content).toContainText('Everything in Kubernetes is an object')

    await hint.getByRole('button', { name: 'Dismiss' }).click()
    await expect(hint).toBeHidden()
    await page.reload()
    await expect(ui(page).qnum).toHaveText('Lesson 0')
    await expect(hint).toBeHidden()
  })

  test('hides the hint once a question is passed', async ({ page, api }) => {
    api.state.passed = [1]
    await page.goto('/')
    await expect(ui(page).title).toBeVisible()
    await expect(page.locator('.banner.hint')).toHaveCount(0)
  })

  test('ignores a remembered question that no longer exists', async ({ page }) => {
    await seedStorage(page, { 'ckad.lastView': { kind: 'question', n: 99 } })
    await page.goto('/')
    await expect(ui(page).qnum).toHaveText('Q1')
  })
})

test.describe('moving around', () => {
  test('Prev and Next follow the learning path, through Lesson 0', async ({ page }) => {
    await page.goto('/')
    const u = ui(page)
    await expect(u.qnum).toHaveText('Q1')

    await u.next.click()
    await expect(u.qnum).toHaveText('Q5')
    await u.next.click()
    await expect(u.qnum).toHaveText('Q3')
    await u.prev.click()
    await u.prev.click()
    await expect(u.qnum).toHaveText('Q1')

    await u.prev.click()
    await expect(u.qnum).toHaveText('Lesson 0')
    await expect(u.prev).toBeDisabled()
    await expect(u.next).toHaveText('Start: Q1 ▶')
    await expect(u.check).toHaveCount(0)
    await u.next.click()
    await expect(u.qnum).toHaveText('Q1')
  })

  test('Next is disabled on the last question', async ({ page }) => {
    await seedStorage(page, { 'ckad.lastView': { kind: 'question', n: 4 } })
    await page.goto('/')
    await expect(ui(page).qnum).toHaveText('Q4')
    await expect(ui(page).next).toBeDisabled()
  })

  test('Alt+Arrow keys navigate, even while the terminal has focus', async ({ page }) => {
    await page.goto('/')
    const u = ui(page)
    await expect(u.termDot).toHaveClass(/open/)
    await page.locator('.term-body').click()

    await page.keyboard.press('Alt+ArrowRight')
    await expect(u.qnum).toHaveText('Q5')
    await page.keyboard.press('Alt+ArrowLeft')
    await expect(u.qnum).toHaveText('Q1')
  })

  test('remembers the open question across reloads', async ({ page }) => {
    await page.goto('/')
    await ui(page).next.click()
    await ui(page).next.click()
    await expect(ui(page).qnum).toHaveText('Q3')
    await page.reload()
    await expect(ui(page).qnum).toHaveText('Q3')
  })
})

test.describe('course drawer', () => {
  test('lists every section with progress marks and opens a question', async ({ page, api }) => {
    api.state.passed = [1]
    await page.goto('/')
    const u = ui(page)
    await expect(u.drawer).toBeHidden()

    await page.getByRole('button', { name: 'Course', exact: true }).click()
    await expect(u.drawer).toBeVisible()
    await expect(u.drawer.getByRole('heading')).toHaveText([
      'Course',
      'Pods & kubectl basics',
      'Configuration',
      'Deployments & Services',
    ])
    const q1 = u.drawer.getByRole('button', { name: /Q1 Namespace and pod inventory/ })
    const q5 = u.drawer.getByRole('button', { name: /Q5 Multi-container pod/ })
    await expect(q1.locator('.status')).toHaveText('✔')
    await expect(q5.locator('.status')).toHaveText('▶')
    await expect(q5).toHaveClass(/current/)

    await u.drawer.getByRole('button', { name: /Q2 Rolling update and rollback/ }).click()
    await expect(u.drawer).toBeHidden()
    await expect(u.qnum).toHaveText('Q2')
  })

  test('closes with Escape and with a click outside', async ({ page }) => {
    await page.goto('/')
    const u = ui(page)
    await page.getByRole('button', { name: 'Course', exact: true }).click()
    await expect(u.drawer).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(u.drawer).toBeHidden()

    await page.getByRole('button', { name: 'Course', exact: true }).click()
    await expect(u.drawer).toBeVisible()
    await page.mouse.click(1200, 450)
    await expect(u.drawer).toBeHidden()
  })

  test('cannot be focused while closed', async ({ page }) => {
    await page.goto('/')
    await expect(ui(page).title).toBeVisible()
    const item = page.locator('.drawer .drawer-item').first()
    await item.focus()
    await expect(item).not.toBeFocused()

    await page.getByRole('button', { name: 'Course', exact: true }).click()
    await item.focus()
    await expect(item).toBeFocused()
  })
})
