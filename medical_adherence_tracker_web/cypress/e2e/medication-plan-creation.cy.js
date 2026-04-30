// Medication schedule creation form: field validation, frequency chip logic, date constraints and successful submission. 
// No live Supabase

const PATIENT_ID  = 'pat-uuid-001'
const PLAN_URL    = `/patients/${PATIENT_ID}/plan/new`

function setupPlanIntercepts(existingPlans = []) {
  cy.intercept('GET', '**/rest/v1/profile*', (req) => {
    const isSingle = (req.headers['accept'] ?? '').includes('pgrst.object')
    req.reply({
      statusCode: 200,
      body: isSingle
        ? { id: PATIENT_ID, name: 'Patient', surname: 'One', role: 'patient', avatar_url: null }
        : [{ id: PATIENT_ID, name: 'Patient', surname: 'One', role: 'patient', avatar_url: null }],
    })
  }).as('profileReq')

  cy.intercept('GET', '**/rest/v1/medication_plan*', {
    statusCode: 200,
    body: existingPlans,
  }).as('planList')

  cy.intercept('POST', '**/rest/v1/medication_plan*', {
    statusCode: 201,
    body: [],
  }).as('createPlan')
}

describe('Schedule Creation Form', () => {
  beforeEach(() => {
    setupPlanIntercepts()
    cy.login()
    cy.visit(PLAN_URL)
    cy.get('[data-cy="create-plan-form"]').should('be.visible')
  })

  // Required field validation
  it('shows the frequency hint when no day is selected on load', () => {
    cy.get('[data-cy="freq-hint"]').should('be.visible').and('contain', 'at least one day')
  })

  it('disables the submit button when no frequency day is selected', () => {
    cy.get('[data-cy="submit-plan-btn"]').should('be.disabled')
  })

  it('enables the submit button once a day chip is selected', () => {
    cy.get('[data-cy="day-chip"][data-day="mo"]').click()
    cy.get('[data-cy="submit-plan-btn"]').should('not.be.disabled')
  })

  it('enforces HTML5 required on plan name', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="plan-name-input"]').clear()
    cy.get('[data-cy="submit-plan-btn"]').click()
    cy.get('[data-cy="plan-name-input"]').then($el => {
      expect(($el[0]).validity.valueMissing).to.be.true
    })
  })

  it('enforces HTML5 required on medication name', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="plan-name-input"]').type('Morning Routine')
    cy.get('[data-cy="medication-name-input"]').clear()
    cy.get('[data-cy="submit-plan-btn"]').click()
    cy.get('[data-cy="medication-name-input"]').then($el => {
      expect(($el[0]).validity.valueMissing).to.be.true
    })
  })

  it('enforces HTML5 required on dosage', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="plan-name-input"]').type('Morning Routine')
    cy.get('[data-cy="medication-name-input"]').type('Ibuprofen')
    cy.get('[data-cy="dosage-input"]').clear()
    cy.get('[data-cy="submit-plan-btn"]').click()
    cy.get('[data-cy="dosage-input"]').then($el => {
      expect(($el[0]).validity.valueMissing).to.be.true
    })
  })

  // Frequency chip logic
  it('selecting "Everyday" hides the frequency hint', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="freq-hint"]').should('not.exist')
  })

  it('deselecting "Everyday" shows the frequency hint again', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="freq-hint"]').should('be.visible')
  })

  it('selecting individual days hides the frequency hint', () => {
    cy.get('[data-cy="day-chip"][data-day="mo"]').click()
    cy.get('[data-cy="day-chip"][data-day="we"]').click()
    cy.get('[data-cy="freq-hint"]').should('not.exist')
  })

  it('selecting "Everyday" after individual days deselects specific days', () => {
    cy.get('[data-cy="day-chip"][data-day="mo"]').click()
    cy.get('[data-cy="day-chip"][data-day="we"]').click()
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="day-chip"][data-day="daily"]').should('have.class', 'selected')
  })

  // Date range validation
  it('shows the dose estimate when valid start and end dates are set', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="start-date-input"]').type('2026-05-01')
    cy.get('[data-cy="end-date-input"]').type('2026-05-31')
    cy.get('[data-cy="dose-estimate"]').should('be.visible').and('contain', '31')
  })

  it('does not show the dose estimate when end date equals start date minus 1', () => {
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="start-date-input"]').type('2026-06-15')
    cy.get('[data-cy="dose-estimate"]').should('not.exist')
  })

  // Units dropdown
  it('contains all expected unit options', () => {
    const expectedUnits = ['mg', 'g', 'ml', 'tablet', 'capsule', 'drop', 'IU']
    expectedUnits.forEach(unit => {
      cy.get('[data-cy="units-select"]').find(`option[value="${unit}"]`).should('exist')
    })
  })

  // Successful submission
  it('shows a success message after a valid plan is created', () => {
    cy.get('[data-cy="plan-name-input"]').clear().type('Test Plan')
    cy.get('[data-cy="medication-name-input"]').clear().type('Paracetamol')
    cy.get('[data-cy="dosage-input"]').clear().type('500')
    cy.get('[data-cy="units-select"]').select('mg')
    cy.get('[data-cy="time-input"]').type('08:00')
    cy.get('[data-cy="day-chip"][data-day="daily"]').click()
    cy.get('[data-cy="start-date-input"]').type('2026-05-01')
    cy.get('[data-cy="end-date-input"]').type('2026-06-30')
    cy.get('[data-cy="submit-plan-btn"]').click()
    cy.get('[data-cy="success-message"]').should('be.visible').and('contain', 'successfully')
  })
})
