// Patient list and dashboard rendering and table structure
// No Supabase calls

const DOCTOR_PROFILE = {
  id: 'doc-uuid-001', name: 'Test', surname: 'Doctor', role: 'doctor', avatar_url: null,
}

describe('Dashboard — Patient List', () => {
  let patients, profiles

  before(() => {
    cy.fixture('mockPatients.json').then(data => {
      patients = data.patients
      profiles = data.patientProfiles
    })
  })

  function setupPatientIntercepts() {
    cy.intercept('GET', '**/rest/v1/patient*', { statusCode: 200, body: patients }).as('patientList')

    cy.intercept('GET', '**/rest/v1/profile*', (req) => {
      const isSingle = (req.headers['accept'] ?? '').includes('pgrst.object')
      req.reply({ statusCode: 200, body: isSingle ? DOCTOR_PROFILE : profiles })
    }).as('profileList')

    cy.intercept('HEAD', '**/rest/v1/**', {
      statusCode: 200, headers: { 'Content-Range': '0-2/3' },
    }).as('headCatch')
  }

  beforeEach(() => {
    cy.login()
    setupPatientIntercepts()
    cy.get('[data-cy="nav-patients"]').click()
    cy.get('[data-cy="patient-list"]').should('be.visible')
    cy.get('[data-cy="patient-row"]').should('have.length', 3)
  })

  // Table rendering
  it('renders the correct patient names', () => {
    cy.get('[data-cy="patient-row"]').eq(0).find('[data-cy="patient-name"]').should('contain', 'Patient One')
    cy.get('[data-cy="patient-row"]').eq(1).find('[data-cy="patient-name"]').should('contain', 'Patient Two')
    cy.get('[data-cy="patient-row"]').eq(2).find('[data-cy="patient-name"]').should('contain', 'Patient Three')
  })

  it('renders truncated uppercase patient IDs', () => {
    cy.get('[data-cy="patient-row"]').eq(0)
      .find('[data-cy="patient-id-badge"]')
      .invoke('text')
      .should('match', /^[A-Z0-9\-]{8}$/)
  })

  it('renders condition tags for each patient', () => {
    cy.get('[data-cy="patient-row"]').eq(0)
      .find('[data-cy="condition-tag"]')
      .should('have.length.at.least', 1)
  })

  it('truncates patients with more than 2 conditions and shows a +N label', () => {
    cy.get('[data-cy="patient-row"]').eq(2)
      .find('[data-cy="condition-tag"]')
      .should('have.length', 2)
    cy.get('[data-cy="patient-row"]').eq(2).should('contain', '+1')
  })

  // Action buttons
  it('has a View Adherence button for each patient', () => {
    cy.get('[data-cy="patient-row"]')
      .each($row => cy.wrap($row).find('[data-cy="view-adherence-btn"]').should('exist'))
  })

  it('has an Add Plan button for each patient', () => {
    cy.get('[data-cy="patient-row"]')
      .each($row => cy.wrap($row).find('[data-cy="add-plan-btn"]').should('exist'))
  })

  it('navigates to the adherence view when View Adherence is clicked', () => {
    cy.intercept('GET', '**/rest/v1/medication_plan*', { statusCode: 200, body: [] })
    cy.intercept('GET', '**/rest/v1/dose*', { statusCode: 200, body: [] })
    cy.intercept('GET', '**/rest/v1/patient*', { statusCode: 200, body: [] })

    cy.get('[data-cy="patient-row"]').eq(0).find('[data-cy="view-adherence-btn"]').click()
    cy.url().should('include', '/adherence')
  })

  // New patient button
  it('has a New Patient button that navigates to /patients/new', () => {
    cy.get('[data-cy="new-patient-btn"]').should('be.visible').click()
    cy.url().should('include', '/patients/new')
  })

  // Home page stats
  it('shows patient count on the home dashboard', () => {
    cy.visit('/home')
    cy.get('[data-cy="patient-count"]').should('be.visible')
  })

  it('shows the monthly adherence percentage on the home dashboard', () => {
    cy.visit('/home')
    cy.get('[data-cy="adherence-pct"]').should('be.visible')
  })
})
