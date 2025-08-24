;; Compliance Tracker Contract
;; Monitors regulatory compliance, certifications, and audit trails

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-COMPLIANCE-NOT-FOUND (err u402))
(define-constant ERR-INVALID-SCORE (err u403))
(define-constant ERR-CERTIFICATION-EXPIRED (err u404))

;; Data Variables
(define-data-var next-compliance-id uint u1)
(define-data-var next-audit-id uint u1)
(define-data-var compliance-threshold uint u70) ;; Minimum compliance score

;; Data Maps
(define-map compliance-records
  { compliance-id: uint }
  {
    manufacturer-id: uint,
    regulatory-framework: (string-ascii 100),
    compliance-date: uint,
    compliance-score: uint,
    status: (string-ascii 20),
    expiry-date: uint,
    certification-body: (string-ascii 100),
    requirements-met: uint,
    total-requirements: uint,
    last-audit-date: uint
  }
)

(define-map audit-trails
  { audit-id: uint }
  {
    manufacturer-id: uint,
    audit-type: (string-ascii 50),
    audit-date: uint,
    auditor-id: (string-ascii 100),
    audit-scope: (string-ascii 200),
    findings: (string-ascii 1000),
    recommendations: (string-ascii 1000),
    compliance-score: uint,
    follow-up-required: bool,
    follow-up-date: uint
  }
)

(define-map certification-requirements
  { framework: (string-ascii 100) }
  {
    total-requirements: uint,
    mandatory-tests: uint,
    documentation-items: uint,
    renewal-period: uint,
    grace-period: uint
  }
)

(define-map manufacturer-compliance-summary
  { manufacturer-id: uint }
  {
    overall-score: uint,
    active-certifications: uint,
    expired-certifications: uint,
    pending-audits: uint,
    last-compliance-check: uint,
    next-renewal-date: uint
  }
)

;; Initialize common regulatory frameworks
(map-set certification-requirements
  { framework: "ISO-26262" }
  { total-requirements: u50, mandatory-tests: u20, documentation-items: u30, renewal-period: u26280, grace-period: u2628 }
)

(map-set certification-requirements
  { framework: "SAE-J3016" }
  { total-requirements: u30, mandatory-tests: u15, documentation-items: u15, renewal-period: u17520, grace-period: u1752 }
)

(map-set certification-requirements
  { framework: "NHTSA-AV" }
  { total-requirements: u40, mandatory-tests: u25, documentation-items: u15, renewal-period: u13140, grace-period: u1314 }
)

;; Public Functions

;; Submit compliance record
(define-public (submit-compliance-record
  (manufacturer-id uint)
  (regulatory-framework (string-ascii 100))
  (compliance-score uint)
  (status (string-ascii 20))
  (expiry-date uint)
  (certification-body (string-ascii 100))
  (requirements-met uint)
  (total-requirements uint)
)
  (let
    (
      (compliance-id (var-get next-compliance-id))
      (current-block block-height)
    )
    (asserts! (is-manufacturer-authorized manufacturer-id) ERR-NOT-AUTHORIZED)
    (asserts! (<= compliance-score u100) ERR-INVALID-SCORE)
    (asserts! (> expiry-date current-block) ERR-INVALID-INPUT)
    (asserts! (<= requirements-met total-requirements) ERR-INVALID-INPUT)

    (map-set compliance-records
      { compliance-id: compliance-id }
      {
        manufacturer-id: manufacturer-id,
        regulatory-framework: regulatory-framework,
        compliance-date: current-block,
        compliance-score: compliance-score,
        status: status,
        expiry-date: expiry-date,
        certification-body: certification-body,
        requirements-met: requirements-met,
        total-requirements: total-requirements,
        last-audit-date: current-block
      }
    )

    ;; Update manufacturer compliance summary
    (update-compliance-summary manufacturer-id compliance-score)

    (var-set next-compliance-id (+ compliance-id u1))
    (ok compliance-id)
  )
)

;; Submit audit trail
(define-public (submit-audit-trail
  (manufacturer-id uint)
  (audit-type (string-ascii 50))
  (auditor-id (string-ascii 100))
  (audit-scope (string-ascii 200))
  (findings (string-ascii 1000))
  (recommendations (string-ascii 1000))
  (compliance-score uint)
  (follow-up-required bool)
  (follow-up-date uint)
)
  (let
    (
      (audit-id (var-get next-audit-id))
      (current-block block-height)
    )
    (asserts! (is-manufacturer-authorized manufacturer-id) ERR-NOT-AUTHORIZED)
    (asserts! (<= compliance-score u100) ERR-INVALID-SCORE)
    (asserts! (> (len findings) u0) ERR-INVALID-INPUT)

    (map-set audit-trails
      { audit-id: audit-id }
      {
        manufacturer-id: manufacturer-id,
        audit-type: audit-type,
        audit-date: current-block,
        auditor-id: auditor-id,
        audit-scope: audit-scope,
        findings: findings,
        recommendations: recommendations,
        compliance-score: compliance-score,
        follow-up-required: follow-up-required,
        follow-up-date: follow-up-date
      }
    )

    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

;; Update compliance status
(define-public (update-compliance-status (compliance-id uint) (new-status (string-ascii 20)) (new-score uint))
  (let
    (
      (compliance (unwrap! (map-get? compliance-records { compliance-id: compliance-id }) ERR-COMPLIANCE-NOT-FOUND))
    )
    (asserts! (is-manufacturer-authorized (get manufacturer-id compliance)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-score u100) ERR-INVALID-SCORE)

    (map-set compliance-records
      { compliance-id: compliance-id }
      (merge compliance {
        status: new-status,
        compliance-score: new-score,
        last-audit-date: block-height
      })
    )

    ;; Update summary
    (update-compliance-summary (get manufacturer-id compliance) new-score)
    (ok true)
  )
)

;; Renew certification
(define-public (renew-certification (compliance-id uint) (new-expiry-date uint))
  (let
    (
      (compliance (unwrap! (map-get? compliance-records { compliance-id: compliance-id }) ERR-COMPLIANCE-NOT-FOUND))
    )
    (asserts! (is-manufacturer-authorized (get manufacturer-id compliance)) ERR-NOT-AUTHORIZED)
    (asserts! (> new-expiry-date block-height) ERR-INVALID-INPUT)

    (map-set compliance-records
      { compliance-id: compliance-id }
      (merge compliance {
        expiry-date: new-expiry-date,
        status: "active",
        compliance-date: block-height
      })
    )
    (ok true)
  )
)

;; Check compliance status
(define-public (check-compliance-status (manufacturer-id uint))
  (let
    (
      (summary (default-to
        { overall-score: u0, active-certifications: u0, expired-certifications: u0, pending-audits: u0, last-compliance-check: u0, next-renewal-date: u0 }
        (map-get? manufacturer-compliance-summary { manufacturer-id: manufacturer-id })
      ))
    )
    (asserts! (is-manufacturer-authorized manufacturer-id) ERR-NOT-AUTHORIZED)

    (map-set manufacturer-compliance-summary
      { manufacturer-id: manufacturer-id }
      (merge summary { last-compliance-check: block-height })
    )

    (ok (>= (get overall-score summary) (var-get compliance-threshold)))
  )
)

;; Read-only Functions

;; Get compliance record
(define-read-only (get-compliance-record (compliance-id uint))
  (map-get? compliance-records { compliance-id: compliance-id })
)

;; Get audit trail
(define-read-only (get-audit-trail (audit-id uint))
  (map-get? audit-trails { audit-id: audit-id })
)

;; Get manufacturer compliance summary
(define-read-only (get-compliance-summary (manufacturer-id uint))
  (map-get? manufacturer-compliance-summary { manufacturer-id: manufacturer-id })
)

;; Get certification requirements
(define-read-only (get-certification-requirements (framework (string-ascii 100)))
  (map-get? certification-requirements { framework: framework })
)

;; Check if certification is expired
(define-read-only (is-certification-expired (compliance-id uint))
  (match (map-get? compliance-records { compliance-id: compliance-id })
    compliance (> block-height (get expiry-date compliance))
    true
  )
)

;; Get compliance threshold
(define-read-only (get-compliance-threshold)
  (var-get compliance-threshold)
)

;; Get total compliance records
(define-read-only (get-total-compliance-records)
  (- (var-get next-compliance-id) u1)
)

;; Get total audits
(define-read-only (get-total-audits)
  (- (var-get next-audit-id) u1)
)

;; Private Functions

;; Update manufacturer compliance summary
(define-private (update-compliance-summary (manufacturer-id uint) (new-score uint))
  (let
    (
      (current-summary (default-to
        { overall-score: u0, active-certifications: u0, expired-certifications: u0, pending-audits: u0, last-compliance-check: u0, next-renewal-date: u0 }
        (map-get? manufacturer-compliance-summary { manufacturer-id: manufacturer-id })
      ))
    )
    (map-set manufacturer-compliance-summary
      { manufacturer-id: manufacturer-id }
      (merge current-summary {
        overall-score: new-score,
        last-compliance-check: block-height
      })
    )
  )
)

;; Check if manufacturer is authorized
(define-private (is-manufacturer-authorized (manufacturer-id uint))
  ;; In a real implementation, this would call the manufacturer registry contract
  (> manufacturer-id u0)
)
