// Patient creation form: field rendering, HTML5 validation, API error display and successful creation redirect
// No Supabase calls, no live DB

describe('New Patient Form', () => {
  function setupCreateIntercepts() {
    cy.intercept('POST', '**/auth/v1/signup*', {
      statusCode: 200,
      body: { user: { id: 'new-patient-uuid', email: 'newpatient@test.com' }, session: null },
    }).as('signupPatient')

    cy.intercept('POST', '**/auth/v1/token*', (req) => {
      if ((req.body ?? '').toString().includes('refresh_token')) {
        req.reply({
          statusCode: 200,
          body: {
            access_token: 'refreshed-token', refresh_token: 'new-refresh',
            expires_in: 3600, token_type: 'bearer',
            user: { id: 'doc-uuid-001', email: 'doctor@test.com' },
          },
        })
      } else {
        req.continue()
      }
    }).as('tokenRefresh')

    cy.intercept('POST', '**/rest/v1/profile*', { statusCode: 201, body: [] }).as('insertProfile')
    cy.intercept('POST', '**/rest/v1/patient*', { statusCode: 201, body: [] }).as('insertPatient')
  }

  beforeEach(() => {
    cy.login()
    cy.visit('/patients/new')
    cy.get('[data-cy="create-patient-form"]').should('be.visible')
  })

  // Form rendering
  it('displays all required form fields', () => {
    cy.get('[data-cy="name-input"]').should('be.visible')
    cy.get('[data-cy="surname-input"]').should('be.visible')
    cy.get('[data-cy="email-input"]').should('be.visible')
    cy.get('[data-cy="password-input"]').should('be.visible')
    cy.get('[data-cy="conditions-input"]').should('be.visible')
    cy.get('[data-cy="submit-btn"]').should('be.visible').and('not.be.disabled')
  })

  it('does not show an error message on initial load', () => {
    cy.get('[data-cy="error-message"]').should('not.exist')
  })

  // Navigation
  it('New Patient button in the patient list navigates here', () => {
    cy.intercept('GET', '**/rest/v1/patient*', { statusCode: 200, body: [] }).as('patientList')
    cy.visit('/patients')
    cy.get('[data-cy="new-patient-btn"]').should('be.visible').click()
    cy.url().should('include', '/patients/new')
  })

  // Required field validation
  it('requires the first name field', () => {
    cy.get('[data-cy="surname-input"]').type('Doe')
    cy.get('[data-cy="email-input"]').type('p@test.com')
    cy.get('[data-cy="password-input"]').type('Password1!')
    cy.get('[data-cy="submit-btn"]').click()
    cy.get('[data-cy="name-input"]').then($el => {
      expect(($el[0]).validity.valueMissing).to.be.true
    })
  })

  it('requires the email field', () => {
    cy.get('[data-cy="name-input"]').type('Jane')
    cy.get('[data-cy="surname-input"]').type('Doe')
    cy.get('[data-cy="password-input"]').type('Password1!')
    cy.get('[data-cy="submit-btn"]').click()
    cy.get('[data-cy="email-input"]').then($el => {
      expect(($el[0]).validity.valueMissing).to.be.true
    })
  })

  // API error handling
  it('shows an error message when patient signup fails', () => {
    cy.intercept('POST', '**/auth/v1/signup*', {
      statusCode: 422,
      body: { message: 'User already registered' },
    }).as('signupFail')

    cy.get('[data-cy="name-input"]').type('Jane')
    cy.get('[data-cy="surname-input"]').type('Doe')
    cy.get('[data-cy="email-input"]').type('existing@test.com')
    cy.get('[data-cy="password-input"]').type('Password1!')
    cy.get('[data-cy="submit-btn"]').click()

    cy.get('[data-cy="error-message"]').should('be.visible')
    cy.url().should('include', '/patients/new')
  })

  // Successful creation
  it('redirects to /patients after successful patient creation', () => {
    setupCreateIntercepts()

    cy.get('[data-cy="name-input"]').type('Jane')
    cy.get('[data-cy="surname-input"]').type('Doe')
    cy.get('[data-cy="email-input"]').type('newpatient@test.com')
    cy.get('[data-cy="password-input"]').type('Password1!')
    cy.get('[data-cy="conditions-input"]').type('Diabetes, Hypertension')
    cy.get('[data-cy="submit-btn"]').click()

    cy.wait('@insertPatient')
    cy.url().should('include', '/patients')
    cy.url().should('not.include', '/patients/new')
  })

  it('disables the submit button while creation is in progress', () => {
    cy.intercept('POST', '**/auth/v1/signup*', (req) => {
      req.on('response', res => { res.setDelay(400) })
      req.reply({ statusCode: 200, body: { user: { id: 'new-id', email: 'p@test.com' }, session: null } })
    }).as('slowSignup')
    cy.intercept('POST', '**/rest/v1/profile*', { statusCode: 201, body: [] })
    cy.intercept('POST', '**/rest/v1/patient*', { statusCode: 201, body: [] })

    cy.get('[data-cy="name-input"]').type('Jane')
    cy.get('[data-cy="surname-input"]').type('Doe')
    cy.get('[data-cy="email-input"]').type('p@test.com')
    cy.get('[data-cy="password-input"]').type('Password1!')
    cy.get('[data-cy="submit-btn"]').click()
    cy.get('[data-cy="submit-btn"]').should('be.disabled')
  })
})
