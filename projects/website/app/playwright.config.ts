import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3102',
    trace: 'on-first-retry',
  },
  webServer: {
    // Browser tests keep the deliberately unconfigured BFF fixture isolated
    // from the developer's backend, generated credential and running DEV tree.
    command: 'node scripts/start-isolated-e2e-server.mjs',
    url: 'http://localhost:3102',
    gracefulShutdown: { signal: 'SIGTERM', timeout: 10_000 },
    reuseExistingServer: false,
    timeout: 120_000,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],
});
