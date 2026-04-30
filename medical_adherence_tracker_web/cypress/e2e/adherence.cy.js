// Adherence history view: calendar rendering, dose-bar colours, monthly stats percentage accuracy and month navigation

const PATIENT_ID    = 'pat-uuid-001'
const DOCTOR_PROFILE = {
  id: 'doc-uuid-001', name: 'Test', surname: 'Doctor', role: 'doctor', avatar_url: null,
}

describe('Adherence View', () => {
  let plans, doses, patientProfile, patientRecord

  before(() => {
    cy.fixture('mockPatients.json').then(data => {
      plans         = data.plans.filter(p => p.patient_id === PATIENT_ID)
      patientProfile = data.patientProfiles.find(p => p.id === PATIENT_ID)
      patientRecord  = data.patients.find(p => p.id === PATIENT_ID)
    })
    cy.fixture('mockDoseLogs.json').then(data => {
      doses = data.doses.filter(d => d.plan_id === 'plan-uuid-001')
    })
  })

  function setupAdherenceIntercepts() {
    cy.intercept('GET', '**/rest/v1/profile*', (req) => {
      const isSingle   = (req.headers['accept'] ?? '').includes('pgrst.object')
      const forPatient = req.url.includes(PATIENT_ID)
      const body       = forPatient ? patientProfile : DOCTOR_PROFILE
      req.reply({ statusCode: 200, body: isSingle ? body : [body] })
    }).as('profileReq')

    cy.intercept('GET', '**/rest/v1/patient*', (req) => {
      const isSingle = (req.headers['accept'] ?? '').includes('pgrst.object')
      req.reply({ statusCode: 200, body: isSingle ? patientRecord : [patientRecord] })
    }).as('patientReq')

    cy.intercept('GET', '**/rest/v1/medication_plan*', { statusCode: 200, body: plans }).as('planReq')
    cy.intercept('GET', '**/rest/v1/dose*',            { statusCode: 200, body: doses }).as('doseReq')
  }

  beforeEach(() => {
    cy.login()
    cy.clock(new Date(2026, 3, 20, 23, 59, 59).getTime())
    setupAdherenceIntercepts()
    cy.visit(`/patients/${PATIENT_ID}/adherence`)
    cy.get('[data-cy="adherence-page"]').should('be.visible')
    cy.get('[data-cy="calendar-body"]').should('be.visible')
  })

  // Page structure
  it('renders the patient name in the header', () => {
    cy.contains('Patient One').should('exist')
  })

  it('renders the calendar with one row per day in the month', () => {
    cy.get('[data-cy="calendar-row"]').should('have.length', 30)
  })

  it('shows the current month label in the toolbar', () => {
    cy.contains('April 2026').should('exist')
  })

  // Dose bars
  it('renders taken dose bars', () => {
    cy.get('[data-cy="dose-bar"][data-status="taken"]').should('have.length.at.least', 1)
  })

  it('renders missed dose bars', () => {
    cy.get('[data-cy="dose-bar"][data-status="missed"]').should('have.length.at.least', 1)
  })

  it('shows a taken bar on April 1st', () => {
    cy.get('[data-cy="calendar-row"][data-date="2026-04-01"]')
      .find('[data-cy="dose-bar"][data-status="taken"]')
      .should('exist')
  })

  it('shows a missed bar on April 18th', () => {
    cy.get('[data-cy="calendar-row"][data-date="2026-04-18"]')
      .find('[data-cy="dose-bar"][data-status="missed"]')
      .should('exist')
  })

  // Monthly stats (frozen at April 20 = 17 taken + 3 missed = 20 total)
  it('shows 17 taken doses in the stats panel', () => {
    cy.get('[data-cy="stat-badge-taken"]').should('contain', '17')
  })

  it('shows 0 late doses in the stats panel', () => {
    cy.get('[data-cy="stat-badge-late"]').should('contain', '0')
  })

  it('shows 0 skipped doses in the stats panel', () => {
    cy.get('[data-cy="stat-badge-skipped"]').should('contain', '0')
  })

  it('shows 3 missed doses in the stats panel', () => {
    cy.get('[data-cy="stat-badge-missed"]').should('contain', '3')
  })

  // Monthly adherence percentage
  it('shows 85 % monthly adherence (17 adherent out of 20 total)', () => {
    cy.get('[data-cy="monthly-adherence-pct"]').should('contain', '85%')
  })

  it('monthly adherence is a numeric percentage between 0 and 100', () => {
    cy.get('[data-cy="monthly-adherence-pct"]')
      .invoke('text')
      .should('match', /^\d{1,3}%$/)
  })

  it('adherence drops below 100 % when there are missed doses', () => {
    cy.get('[data-cy="monthly-adherence-pct"]')
      .invoke('text')
      .then(text => { expect(parseInt(text)).to.be.lessThan(100) })
  })

  it('adherence is above 50 % when most doses are taken', () => {
    cy.get('[data-cy="monthly-adherence-pct"]')
      .invoke('text')
      .then(text => { expect(parseInt(text)).to.be.greaterThan(50) })
  })

  // Month navigation
  it('disables the next-month button when viewing the current month', () => {
    cy.get('[data-cy="month-nav-next"]').should('be.disabled')
  })

  it('navigates to March 2026 when prev is clicked', () => {
    cy.get('[data-cy="month-nav-prev"]').click()
    cy.contains('March 2026').should('exist')
  })

  it('re-enables the next-month button after navigating back one month', () => {
    cy.get('[data-cy="month-nav-prev"]').click()
    cy.get('[data-cy="month-nav-next"]').should('not.be.disabled')
  })

  it('returns to April after clicking next following a back navigation', () => {
    cy.get('[data-cy="month-nav-prev"]').click()
    cy.get('[data-cy="month-nav-next"]').click()
    cy.contains('April 2026').should('exist')
  })

  // Navigation link
  it('has an Add Medication Plan link that goes to the plan creation page', () => {
    cy.contains('Add Medication Plan').should('be.visible').click()
    cy.url().should('include', `/patients/${PATIENT_ID}/plan/new`)
  })
})
