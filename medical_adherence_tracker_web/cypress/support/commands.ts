/// <reference types="cypress" />

// Private constants — not exported, so this file stays a simple side-effect module
const DOCTOR_ID = 'doc-uuid-001'

const DOCTOR_PROFILE = {
  id: DOCTOR_ID, name: 'Test', surname: 'Doctor', role: 'doctor', avatar_url: null,
}

// Build a minimal JWT that the Supabase JS SDK can base64-decode without
// signature verification (the client never verifies signatures).
function makeTestJwt(sub: string, email: string): string {
  const header  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
  const payload = btoa(
    JSON.stringify({ sub, email, role: 'authenticated', aud: 'authenticated', exp: 9999999999 }),
  ).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  return `${header}.${payload}.test-sig`
}

Cypress.Commands.add('login', (email: string = 'doctor@test.com', password: string = 'Password123!') => {
  const accessToken = makeTestJwt(DOCTOR_ID, email)

  cy.intercept('POST', '**/auth/v1/token*', {
    statusCode: 200,
    body: {
      access_token: accessToken, token_type: 'bearer',
      expires_in: 3600, expires_at: 9999999999,
      refresh_token: 'test-refresh-token',
      user: {
        id: DOCTOR_ID, aud: 'authenticated', role: 'authenticated', email,
        email_confirmed_at: '2024-01-01T00:00:00Z',
        app_metadata: { provider: 'email', providers: ['email'] },
        user_metadata: {}, created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-01T00:00:00Z',
      },
    },
  }).as('authToken')

  cy.intercept('GET', '**/auth/v1/user*', {
    statusCode: 200,
    body: { id: DOCTOR_ID, aud: 'authenticated', role: 'authenticated', email },
  }).as('authUser')

  // Handles both .single() (Accept: pgrst.object → plain object) and array selects
  cy.intercept('GET', '**/rest/v1/profile*', (req) => {
    const isSingle = (req.headers['accept'] ?? '').includes('pgrst.object')
    req.reply({ statusCode: 200, body: isSingle ? DOCTOR_PROFILE : [DOCTOR_PROFILE] })
  }).as('profileRequest')

  // HEAD is used by the home-page patient count query (count: 'exact', head: true)
  cy.intercept('HEAD', '**/rest/v1/patient*', {
    statusCode: 200, headers: { 'Content-Range': '0-2/3' },
  }).as('patientCount')

  // Home-page adherence widget — return empty so stats show 0% without errors
  cy.intercept('GET', '**/rest/v1/medication_plan*', { statusCode: 200, body: [] }).as('planList')
  cy.intercept('GET', '**/rest/v1/dose*',            { statusCode: 200, body: [] }).as('doseList')

  cy.visit('/login')
  cy.get('[data-cy="email-input"]').type(email)
  cy.get('[data-cy="password-input"]').type(password)
  cy.get('[data-cy="submit-btn"]').click()
  cy.url().should('include', '/home')
})

// Marks the file as an ES module (no globals leaked) without exporting anything.
export {}
