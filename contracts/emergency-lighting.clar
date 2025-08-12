;; Emergency Lighting Systems Contract
;; Maintains backup lighting for critical infrastructure

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-SYSTEM-ID (err u401))
(define-constant ERR-SYSTEM-ALREADY-ACTIVE (err u402))
(define-constant ERR-SYSTEM-NOT-FOUND (err u403))
(define-constant ERR-INVALID-BATTERY-LEVEL (err u404))
(define-constant ERR-MAINTENANCE-REQUIRED (err u405))

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var emergency-active bool false)
(define-data-var total-systems uint u0)
(define-data-var systems-online uint u0)

;; Data Maps
(define-map emergency-systems
  { system-id: uint }
  {
    location: (string-ascii 100),
    facility-type: (string-ascii 30),
    system-type: (string-ascii 20),
    battery-level: uint,
    last-test: uint,
    status: (string-ascii 20),
    backup-duration: uint,
    installation-date: uint,
    maintenance-due: uint
  }
)

(define-map system-activations
  { activation-id: uint }
  {
    system-id: uint,
    activation-time: uint,
    deactivation-time: (optional uint),
    reason: (string-ascii 100),
    operator: principal,
    battery-consumed: (optional uint)
  }
)

(define-map maintenance-records
  { system-id: uint, record-id: uint }
  {
    maintenance-type: (string-ascii 30),
    performed-by: principal,
    date-performed: uint,
    issues-found: (string-ascii 200),
    parts-replaced: (string-ascii 100),
    next-maintenance: uint
  }
)

(define-map authorized-operators principal bool)
(define-map maintenance-technicians principal bool)

;; Counters
(define-data-var next-activation-id uint u1)
(define-data-var next-record-id uint u1)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized-operator)
  (default-to false (map-get? authorized-operators tx-sender))
)

(define-private (is-maintenance-technician)
  (default-to false (map-get? maintenance-technicians tx-sender))
)

;; Administrative Functions
(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-operators operator true))
  )
)

(define-public (add-maintenance-technician (technician principal))
  (begin
    (asserts! (or (is-contract-owner) (is-authorized-operator)) ERR-NOT-AUTHORIZED)
    (ok (map-set maintenance-technicians technician true))
  )
)

;; Emergency System Management
(define-public (register-emergency-system
  (system-id uint)
  (location (string-ascii 100))
  (facility-type (string-ascii 30))
  (system-type (string-ascii 20))
  (backup-duration uint)
)
  (begin
    (asserts! (or (is-contract-owner) (is-authorized-operator)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? emergency-systems { system-id: system-id })) ERR-SYSTEM-ALREADY-ACTIVE)
    (map-set emergency-systems
      { system-id: system-id }
      {
        location: location,
        facility-type: facility-type,
        system-type: system-type,
        battery-level: u100,
        last-test: block-height,
        status: "standby",
        backup-duration: backup-duration,
        installation-date: block-height,
        maintenance-due: (+ block-height u8760) ;; Approximately 1 year in blocks
      }
    )
    (var-set total-systems (+ (var-get total-systems) u1))
    (var-set systems-online (+ (var-get systems-online) u1))
    (ok true)
  )
)

(define-public (update-battery-level (system-id uint) (battery-level uint))
  (let ((system-data (unwrap! (map-get? emergency-systems { system-id: system-id }) ERR-SYSTEM-NOT-FOUND)))
    (asserts! (is-maintenance-technician) ERR-NOT-AUTHORIZED)
    (asserts! (<= battery-level u100) ERR-INVALID-BATTERY-LEVEL)
    (ok (map-set emergency-systems
      { system-id: system-id }
      (merge system-data {
        battery-level: battery-level,
        last-test: block-height
      })
    ))
  )
)

;; Emergency Activation
(define-public (activate-emergency-system (system-id uint) (reason (string-ascii 100)))
  (let
    ((system-data (unwrap! (map-get? emergency-systems { system-id: system-id }) ERR-SYSTEM-NOT-FOUND))
     (activation-id (var-get next-activation-id)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status system-data) "standby") ERR-SYSTEM-ALREADY-ACTIVE)
    (asserts! (> (get battery-level system-data) u10) ERR-INVALID-BATTERY-LEVEL)

    ;; Update system status
    (map-set emergency-systems
      { system-id: system-id }
      (merge system-data { status: "active" })
    )

    ;; Record activation
    (map-set system-activations
      { activation-id: activation-id }
      {
        system-id: system-id,
        activation-time: block-height,
        deactivation-time: none,
        reason: reason,
        operator: tx-sender,
        battery-consumed: none
      }
    )

    (var-set next-activation-id (+ activation-id u1))
    (var-set emergency-active true)
    (ok activation-id)
  )
)

(define-public (deactivate-emergency-system (system-id uint) (battery-consumed uint))
  (let ((system-data (unwrap! (map-get? emergency-systems { system-id: system-id }) ERR-SYSTEM-NOT-FOUND)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status system-data) "active") ERR-SYSTEM-NOT-FOUND)
    (asserts! (<= battery-consumed (get battery-level system-data)) ERR-INVALID-BATTERY-LEVEL)

    ;; Update system status and battery
    (map-set emergency-systems
      { system-id: system-id }
      (merge system-data {
        status: "standby",
        battery-level: (- (get battery-level system-data) battery-consumed)
      })
    )

    ;; Find and update the most recent activation record
    ;; In a real implementation, this would need more sophisticated logic
    (ok true)
  )
)

(define-public (activate-all-emergency-systems (reason (string-ascii 100)))
  (begin
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (var-set emergency-active true)
    ;; In a real implementation, this would iterate through all systems
    (ok true)
  )
)

(define-public (deactivate-all-emergency-systems)
  (begin
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (var-set emergency-active false)
    ;; In a real implementation, this would iterate through all active systems
    (ok true)
  )
)

;; Maintenance Management
(define-public (schedule-maintenance (system-id uint) (maintenance-date uint))
  (let ((system-data (unwrap! (map-get? emergency-systems { system-id: system-id }) ERR-SYSTEM-NOT-FOUND)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (ok (map-set emergency-systems
      { system-id: system-id }
      (merge system-data { maintenance-due: maintenance-date })
    ))
  )
)

(define-public (perform-maintenance
  (system-id uint)
  (maintenance-type (string-ascii 30))
  (issues-found (string-ascii 200))
  (parts-replaced (string-ascii 100))
  (next-maintenance uint)
)
  (let
    ((system-data (unwrap! (map-get? emergency-systems { system-id: system-id }) ERR-SYSTEM-NOT-FOUND))
     (record-id (var-get next-record-id)))
    (asserts! (is-maintenance-technician) ERR-NOT-AUTHORIZED)

    ;; Record maintenance
    (map-set maintenance-records
      { system-id: system-id, record-id: record-id }
      {
        maintenance-type: maintenance-type,
        performed-by: tx-sender,
        date-performed: block-height,
        issues-found: issues-found,
        parts-replaced: parts-replaced,
        next-maintenance: next-maintenance
      }
    )

    ;; Update system maintenance date
    (map-set emergency-systems
      { system-id: system-id }
      (merge system-data {
        maintenance-due: next-maintenance,
        last-test: block-height,
        battery-level: u100 ;; Assume battery is replaced/recharged during maintenance
      })
    )

    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

;; System Testing
(define-public (perform-system-test (system-id uint) (test-duration uint))
  (let ((system-data (unwrap! (map-get? emergency-systems { system-id: system-id }) ERR-SYSTEM-NOT-FOUND)))
    (asserts! (is-maintenance-technician) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status system-data) "standby") ERR-SYSTEM-ALREADY-ACTIVE)
    (asserts! (> (get battery-level system-data) u20) ERR-INVALID-BATTERY-LEVEL)

    ;; Update last test date and consume small amount of battery for test
    (ok (map-set emergency-systems
      { system-id: system-id }
      (merge system-data {
        last-test: block-height,
        battery-level: (- (get battery-level system-data) u5) ;; Small battery consumption for test
      })
    ))
  )
)

;; Read-only Functions
(define-read-only (get-emergency-system (system-id uint))
  (map-get? emergency-systems { system-id: system-id })
)

(define-read-only (get-system-activation (activation-id uint))
  (map-get? system-activations { activation-id: activation-id })
)

(define-read-only (get-maintenance-record (system-id uint) (record-id uint))
  (map-get? maintenance-records { system-id: system-id, record-id: record-id })
)

(define-read-only (is-emergency-active)
  (var-get emergency-active)
)

(define-read-only (get-system-stats)
  {
    total-systems: (var-get total-systems),
    systems-online: (var-get systems-online),
    emergency-active: (var-get emergency-active)
  }
)

(define-read-only (system-needs-maintenance (system-id uint))
  (match (map-get? emergency-systems { system-id: system-id })
    system-data (< block-height (get maintenance-due system-data))
    false
  )
)
