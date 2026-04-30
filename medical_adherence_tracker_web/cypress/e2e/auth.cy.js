// Auth flow: login form rendering, credential validation, redirect behaviour and logout
// no supabase calls, no live DB required.

const TEST_EMAIL    = 'doctor@test.com'
const TEST_PASSWORD = 'Password123!'

const INVALID_EMAIL    = 'nobody@example.com'
const INVALID_PASSWORD = 'wrongpassword'

const AUTH_ERROR_BODY = {
  error:             'invalid_grant',
  error_description: 'Invalid login credentials',
}

describe('Authentication', () => {
  beforeEach(() => {
    cy.intercept('GET', '**/rest/v1/**', { statusCode: 200, body: [] }).as('restCatch')
    cy.intercept('HEAD', '**/rest/v1/**', {
      statusCode: 200,
      headers: { 'Content-Range': '0-0/0' },
    }).as('headCatch')
    cy.intercept('GET', '**/auth/v1/user*', {
      statusCode: 401,
      body: { message: 'not authenticated' },
    }).as('noSession')
  })

  // Form rendering
  it('displays the login form with all required elements', () => {
    cy.visit('/login')
    cy.get('[data-cy="login-form"]').should('be.visible')
    cy.get('[data-cy="email-input"]').should('be.visible')
    cy.get('[data-cy="password-input"]').should('be.visible')
    cy.get('[data-cy="submit-btn"]').should('be.visible').and('not.be.disabled')
    cy.get('[data-cy="error-message"]').should('not.exist')
  })

  it('requires the email field to be filled', () => {
    cy.visit('/login')
    cy.get('[data-cy="password-input"]').type(TEST_PASSWORD)
    cy.get('[data-cy="submit-btn"]').click()
    cy.get('[data-cy="email-input"]').then($input => {
      expect(($input[0]).validity.valueMissing).to.be.true
    })
  })

  it('requires the password field to be filled', () => {
    cy.visit('/login')
    cy.get('[data-cy="email-input"]').type(TEST_EMAIL)
    cy.get('[data-cy="submit-btn"]').click()
    cy.get('[data-cy="password-input"]').then($input => {
      expect(($input[0]).validity.valueMissing).to.be.true
    })
  })

  // Invalid credentials
  it('shows an error message for invalid credentials', () => {
    cy.intercept('POST', '**/auth/v1/token*', {
      statusCode: 400,
      body: AUTH_ERROR_BODY,
    }).as('badAuth')
    cy.intercept('GET', '**/rest/v1/profile*', { statusCode: 200, body: [] }).as('profile')

    cy.visit('/login')
    cy.get('[data-cy="email-input"]').type(INVALID_EMAIL)
    cy.get('[data-cy="password-input"]').type(INVALID_PASSWORD)
    cy.get('[data-cy="submit-btn"]').click()

    cy.get('[data-cy="error-message"]').should('be.visible')
    cy.url().should('include', '/login')
  })

  it('disables the submit button while a login request is in-flight', () => {
    cy.intercept('POST', '**/auth/v1/token*', (req) => {
      req.on('response', (res) => { res.setDelay(400) })
      req.reply({ statusCode: 400, body: AUTH_ERROR_BODY })
    }).as('slowAuth')
    cy.intercept('GET', '**/rest/v1/profile*', { statusCode: 200, body: [] })

    cy.visit('/login')
    cy.get('[data-cy="email-input"]').type(TEST_EMAIL)
    cy.get('[data-cy="password-input"]').type(TEST_PASSWORD)
    cy.get('[data-cy="submit-btn"]').click()
    cy.get('[data-cy="submit-btn"]').should('be.disabled')
  })

  // Successful login
  it('redirects to /home after successful login', () => {
    cy.login()
    cy.url().should('include', '/home')
    cy.get('[data-cy="dashboard"]').should('be.visible')
  })

  it('does not display an error message after successful login', () => {
    cy.login()
    cy.get('[data-cy="error-message"]').should('not.exist')
  })

  // Post-login guard
  it('redirects an already-authenticated user away from /login', () => {
    cy.login()
    cy.visit('/login')
    cy.url().should('include', '/home')
  })

  // Logout
  it('logs out the user and redirects to /login', () => {
    cy.intercept('POST', '**/auth/v1/logout*', { statusCode: 204, body: null }).as('logout')
    cy.login()
    cy.get('[data-cy="nav-logout"]').click()
    cy.url().should('include', '/login')
    cy.get('[data-cy="login-form"]').should('be.visible')
  })
})
