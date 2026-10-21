import { defineConfig, devices } from '@playwright/test'

// Two kinds of tests:
// - mock: a production build of the React app with a fake API and terminal
//   (tests/fixtures/mock-api.ts). No cluster needed; safe to run any time.
// - live: the real simulator (.\sim.ps1 up) on CKAD_UI_URL. Read-only: it never resets
//   questions or starts exams. Skipped when the simulator isn't running.
const MOCK_PORT = 5181
const LIVE_URL = process.env.CKAD_UI_URL ?? 'http://127.0.0.1:8090'

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : [['list'], ['html', { open: 'never' }]],
  use: {
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'mock',
      testIgnore: /live\//,
      use: {
        ...devices['Desktop Chrome'],
        baseURL: `http://127.0.0.1:${MOCK_PORT}`,
        viewport: { width: 1400, height: 900 },
      },
    },
    {
      name: 'live',
      testMatch: /live\/.*\.spec\.ts/,
      fullyParallel: false,
      use: {
        ...devices['Desktop Chrome'],
        baseURL: LIVE_URL,
        viewport: { width: 1400, height: 900 },
      },
    },
  ],
  // A fresh production build in dist-test/ (dist/ is what the Go server embeds), served by
  // `vite preview`. --mode test turns off the API proxy, so a mocked test can never reach
  // the real server.
  webServer: {
    command:
      'npx vite build --mode test --outDir dist-test --emptyOutDir --logLevel warn && ' +
      `npx vite preview --mode test --outDir dist-test --host 127.0.0.1 --port ${MOCK_PORT} --strictPort`,
    url: `http://127.0.0.1:${MOCK_PORT}`,
    reuseExistingServer: false,
    timeout: 120_000,
  },
})
