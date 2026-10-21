import AxeBuilder from '@axe-core/playwright'
import type { Page } from '@playwright/test'
import { checkResult } from './fixtures/data'
import { expect, seedStorage, test, ui } from './fixtures/mock-api'

const BLACK = 'rgb(0, 0, 0)'

// Every color the selector's elements use that is not a shade of gray. Status colors
// (pass/fail marks, the connection dot) are the only colors the UI is allowed to use.
async function colorsOutsideGrayscale(page: Page, selector: string): Promise<string[]> {
  return page.evaluate((sel) => {
    const props = ['color', 'background-color', 'border-top-color', 'border-bottom-color', 'border-left-color']
    const found = new Set<string>()
    for (const el of document.querySelectorAll(sel)) {
      if (el.closest('.dot, .status.done, .task .mark, .xterm')) continue
      const style = getComputedStyle(el)
      for (const prop of props) {
        const value = style.getPropertyValue(prop)
        const m = value.match(/rgba?\((\d+), (\d+), (\d+)/)
        if (m && !(m[1] === m[2] && m[2] === m[3])) {
          found.add(`${el.tagName.toLowerCase()}.${String(el.className).replace(/ /g, '.')} ${prop}: ${value}`)
        }
      }
    }
    return [...found]
  }, selector)
}

const CHROME = '.topbar, .topbar *, .banner, .banner *, .question-panel, .question-panel *, .term-toolbar, .term-toolbar *'

async function axe(page: Page) {
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).exclude('.xterm').analyze()
  return results.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)
}

test.describe('dark theme', () => {
  test('is the default: black background, white text', async ({ page }) => {
    await page.goto('/')
    await expect(ui(page).title).toBeVisible()
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
    await expect(page.locator('body')).toHaveCSS('background-color', BLACK)
    await expect(page.locator('body')).toHaveCSS('color', 'rgb(242, 242, 242)')
    await expect(page.locator('.xterm-viewport')).toHaveCSS('background-color', BLACK)
  })

  test('is black and white', async ({ page }) => {
    await page.goto('/')
    await expect(ui(page).title).toBeVisible()
    expect(await colorsOutsideGrayscale(page, CHROME)).toEqual([])
    await page.getByRole('button', { name: 'Course', exact: true }).click()
    await expect(ui(page).drawer).toBeVisible()
    expect(await colorsOutsideGrayscale(page, '.drawer, .drawer *')).toEqual([])
    await page.keyboard.press('Escape')

    await page.getByRole('button', { name: 'Start exam' }).click()
    await ui(page).dialog.getByRole('checkbox').check()
    expect(await colorsOutsideGrayscale(page, '.modal, .modal *')).toEqual([])
    const accent = await ui(page).dialog.getByRole('checkbox').evaluate((el) => getComputedStyle(el).accentColor)
    expect(accent).toBe('rgb(242, 242, 242)')
  })
})

test.describe('light theme', () => {
  test('the toggle switches to white and is remembered', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Toggle theme' }).click()
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
    await expect(page.locator('body')).toHaveCSS('background-color', 'rgb(244, 244, 244)')
    // The terminal stays black, like the exam's.
    await expect(page.locator('.xterm-viewport')).toHaveCSS('background-color', BLACK)

    await page.reload()
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
    await page.getByRole('button', { name: 'Toggle theme' }).click()
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  })

  test('is applied before the app loads (no dark flash)', async ({ page }) => {
    await seedStorage(page, { 'ckad.theme': 'light' })
    // Without the app's JavaScript, only index.html can set the theme.
    await page.route('**/assets/*.js', (route) => route.abort())
    await page.goto('/')
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
  })

  test('is black and white', async ({ page }) => {
    await seedStorage(page, { 'ckad.theme': 'light' })
    await page.goto('/')
    await expect(ui(page).title).toBeVisible()
    expect(await colorsOutsideGrayscale(page, CHROME)).toEqual([])
  })
})

test.describe('accessibility (WCAG 2.1 AA, incl. contrast)', () => {
  for (const theme of ['dark', 'light'] as const) {
    test(`${theme}: question, lesson, results, drawer and dialogs`, async ({ page, api }) => {
      api.checks[1] = checkResult(1, [true, false], null)
      await seedStorage(page, { 'ckad.theme': theme })
      await page.goto('/')
      const u = ui(page)
      await expect(u.title).toBeVisible()
      await expect(u.content).toContainText('Work in namespace')
      expect(await axe(page), 'question view').toEqual([])

      await u.check.click()
      await expect(u.results).toContainText('1/2 tasks')
      await u.tab('Lesson').click()
      await expect(page.locator('.markdown.lesson')).toBeVisible()
      expect(await axe(page), 'lesson + check results').toEqual([])

      await page.getByRole('button', { name: 'Course', exact: true }).click()
      await expect(u.drawer).toBeVisible()
      expect(await axe(page), 'course drawer').toEqual([])
      await page.keyboard.press('Escape')

      await u.reset.click()
      await expect(u.dialog).toBeVisible()
      expect(await axe(page), 'reset dialog').toEqual([])
    })
  }

  test('exam mode and results', async ({ page, api }) => {
    api.startExam(7200 - 300)
    await page.goto('/')
    await expect(ui(page).timer).toHaveClass(/red/)
    expect(await axe(page), 'exam view').toEqual([])
    await page.getByRole('button', { name: 'End exam' }).click()
    await ui(page).dialog.getByRole('button', { name: 'End and grade' }).click()
    await expect(page.locator('.score')).toBeVisible()
    expect(await axe(page), 'results dialog').toEqual([])
  })
})
