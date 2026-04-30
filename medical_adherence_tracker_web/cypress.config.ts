import { defineConfig } from 'cypress'

export default defineConfig({
  projectId: 'e519w2',
  // Never expose real Supabase credentials to Cypress env vars
  allowCypressEnv: false,

  e2e: {
    baseUrl: 'http://localhost:5173',
    specPattern: 'cypress/e2e/**/*.cy.{js,ts}',
    supportFile: 'cypress/support/e2e.ts',
    viewportWidth:  1280,
    viewportHeight: 800,
    // Keep screenshots/videos lean during CI
    screenshotOnRunFailure: true,
    video: false,
    setupNodeEvents(_on, _config) {
      // No custom Node events needed — all mocking is done via cy.intercept()
    },
  },

  component: {
    specPattern: 'cypress/component/**/*.cy.{js,ts}',
    supportFile: 'cypress/support/component.ts',
    viewportWidth:  1024,
    viewportHeight: 768,
    devServer: {
      framework: 'vue',
      bundler:   'vite',
    },
  },
})
