import { expect, PROMPT, test, ui } from './fixtures/mock-api'

test('connects, sizes the shell to the panel and shows the prompt', async ({ page, api }) => {
  await page.goto('/')
  const u = ui(page)
  await expect(u.termDot).toHaveClass(/open/)
  await expect(u.terminal).toContainText(PROMPT.trim())

  await expect.poll(() => api.terminal.current?.messages[0]?.type).toBe('resize')
  const size = api.terminal.current!.messages[0]
  expect(size.cols).toBeGreaterThan(40)
  expect(size.rows).toBeGreaterThan(10)
})

test('sends keystrokes and prints the output', async ({ page, api }) => {
  await page.goto('/')
  const u = ui(page)
  await expect(u.termDot).toHaveClass(/open/)
  await page.locator('.term-body').click()
  await page.keyboard.type('k get po')
  await page.keyboard.press('Enter')
  await expect(u.terminal).toContainText('No resources found in default namespace.')
  expect(api.terminal.input).toBe('k get po\r')
})

test('tells the shell when the panel is resized', async ({ page, api }) => {
  await page.goto('/')
  await expect(ui(page).termDot).toHaveClass(/open/)
  const sizes = () => api.terminal.current!.messages.filter((m) => m.type === 'resize')
  await expect.poll(() => sizes().length).toBeGreaterThan(0)
  const before = sizes().at(-1)!.cols!

  await page.setViewportSize({ width: 1000, height: 900 })
  await expect.poll(() => sizes().at(-1)!.cols!).toBeLessThan(before)
})

test('offers to reconnect when the shell exits', async ({ page, api }) => {
  await page.goto('/')
  const u = ui(page)
  await expect(u.termDot).toHaveClass(/open/)
  const opened = api.terminal.connections.length

  await api.terminal.close()
  await expect(u.termDot).toHaveClass(/closed/)
  const overlay = page.locator('.term-overlay')
  await expect(overlay).toContainText('Disconnected from the terminal.')

  await overlay.getByRole('button', { name: 'Reconnect' }).click()
  await expect(u.termDot).toHaveClass(/open/)
  await expect(overlay).toHaveCount(0)
  expect(api.terminal.connections).toHaveLength(opened + 1)
})

test('New session replaces the shell', async ({ page, api }) => {
  await page.goto('/')
  await expect(ui(page).termDot).toHaveClass(/open/)
  const old = api.terminal.current!
  await page.getByRole('button', { name: 'New session' }).click()
  await expect.poll(() => api.terminal.current).not.toBe(old)
  await expect.poll(() => old.closed).toBe(true)
  await expect(ui(page).termDot).toHaveClass(/open/)
})

test('font size buttons resize the text and are remembered', async ({ page }) => {
  await page.goto('/')
  const rows = ui(page).terminal
  await expect(rows).toHaveCSS('font-size', '14px')
  await page.getByTitle('Bigger font').click()
  await page.getByTitle('Bigger font').click()
  await expect(rows).toHaveCSS('font-size', '16px')
  await page.reload()
  await expect(rows).toHaveCSS('font-size', '16px')
  await page.getByTitle('Smaller font').click()
  await expect(rows).toHaveCSS('font-size', '15px')
})
