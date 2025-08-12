;; Electrical Utility Coordination Contract
;; Manages power supply and electrical infrastructure

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-FACILITY-ID (err u501))
(define-constant ERR-INVALID-CONSUMPTION (err u502))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u503))
(define-constant ERR-BILLING-PERIOD-EXISTS (err u504))
(define-constant ERR-OUTAGE-ACTIVE (err u505))

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-capacity uint u10000000) ;; Total grid capacity in kWh
(define-data-var current-load uint u0)
(define-data-var next-facility-id uint u1)
(define-data-var next-billing-period uint u1)

;; Data Maps
(define-map electrical-facilities
  { facility-id: uint }
  {
    name: (string-ascii 100),
    facility-type: (string-ascii 30),
    location: (string-ascii 100),
    max-capacity: uint,
    current-consumption: uint,
    status: (string-ascii 20),
    connection-date: uint,
    last-maintenance: uint,
    priority-level: uint
  }
)

(define-map power-consumption
  { facility-id: uint, period: uint }
  {
    start-date: uint,
    end-date: uint,
    kwh-consumed: uint,
    peak-demand: uint,
    off-peak-usage: uint,
    cost-per-kwh: uint,
    total-cost: uint
  }
)

(define-map utility-billing
  { billing-period: uint }
  {
    period-start: uint,
    period-end: uint,
    total-consumption: uint,
    total-revenue: uint,
    facilities-billed: uint,
    status: (string-ascii 20)
  }
)

(define-map power-outages
  { outage-id: uint }
  {
    affected-facilities: (list 10 uint),
    start-time: uint,
    end-time: (optional uint),
    cause: (string-ascii 100),
    estimated-restoration: uint,
    status: (string-ascii 20)
  }
)

(define-map grid-infrastructure
  { component-id: uint }
  {
    component-type: (string-ascii 30),
    location: (string-ascii 100),
    capacity: uint,
    status: (string-ascii 20),
    last-inspection: uint,
    maintenance-due: uint
  }
)

(define-map authorized-operators principal bool)
(define-map utility-engineers principal bool)

;; Counters
(define-data-var next-outage-id uint u1)
(define-data-var next-component-id uint u1)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized-operator)
  (default-to false (map-get? authorized-operators tx-sender))
)

(define-private (is-utility-engineer)
  (default-to false (map-get? utility-engineers tx-sender))
)

;; Administrative Functions
(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-operators operator true))
  )
)

(define-public (add-utility-engineer (engineer principal))
  (begin
    (asserts! (or (is-contract-owner) (is-authorized-operator)) ERR-NOT-AUTHORIZED)
    (ok (map-set utility-engineers engineer true))
  )
)

(define-public (update-grid-capacity (new-capacity uint))
  (begin
    (asserts! (is-utility-engineer) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-capacity (var-get current-load)) ERR-INSUFFICIENT-CAPACITY)
    (ok (var-set total-capacity new-capacity))
  )
)

;; Facility Management
(define-public (register-electrical-facility
  (name (string-ascii 100))
  (facility-type (string-ascii 30))
  (location (string-ascii 100))
  (max-capacity uint)
  (priority-level uint)
)
  (let ((facility-id (var-get next-facility-id)))
    (asserts! (or (is-contract-owner) (is-authorized-operator)) ERR-NOT-AUTHORIZED)
    (asserts! (<= (+ (var-get current-load) max-capacity) (var-get total-capacity)) ERR-INSUFFICIENT-CAPACITY)
    (map-set electrical-facilities
      { facility-id: facility-id }
      {
        name: name,
        facility-type: facility-type,
        location: location,
        max-capacity: max-capacity,
        current-consumption: u0,
        status: "connected",
        connection-date: block-height,
        last-maintenance: block-height,
        priority-level: priority-level
      }
    )
    (var-set next-facility-id (+ facility-id u1))
    (var-set current-load (+ (var-get current-load) max-capacity))
    (ok facility-id)
  )
)

(define-public (update-facility-consumption (facility-id uint) (consumption uint))
  (let ((facility-data (unwrap! (map-get? electrical-facilities { facility-id: facility-id }) ERR-INVALID-FACILITY-ID)))
    (asserts! (is-utility-engineer) ERR-NOT-AUTHORIZED)
    (asserts! (<= consumption (get max-capacity facility-data)) ERR-INVALID-CONSUMPTION)
    (ok (map-set electrical-facilities
      { facility-id: facility-id }
      (merge facility-data { current-consumption: consumption })
    ))
  )
)

;; Power Consumption Tracking
(define-public (record-consumption
  (facility-id uint)
  (period uint)
  (start-date uint)
  (end-date uint)
  (kwh-consumed uint)
  (peak-demand uint)
  (off-peak-usage uint)
  (cost-per-kwh uint)
)
  (let ((total-cost (* kwh-consumed cost-per-kwh)))
    (asserts! (is-utility-engineer) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? electrical-facilities { facility-id: facility-id })) ERR-INVALID-FACILITY-ID)
    (asserts! (< start-date end-date) ERR-INVALID-CONSUMPTION)
    (ok (map-set power-consumption
      { facility-id: facility-id, period: period }
      {
        start-date: start-date,
        end-date: end-date,
        kwh-consumed: kwh-consumed,
        peak-demand: peak-demand,
        off-peak-usage: off-peak-usage,
        cost-per-kwh: cost-per-kwh,
        total-cost: total-cost
      }
    ))
  )
)

;; Billing Management
(define-public (create-billing-period
  (period-start uint)
  (period-end uint)
)
  (let ((billing-period (var-get next-billing-period)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (asserts! (< period-start period-end) ERR-INVALID-CONSUMPTION)
    (map-set utility-billing
      { billing-period: billing-period }
      {
        period-start: period-start,
        period-end: period-end,
        total-consumption: u0,
        total-revenue: u0,
        facilities-billed: u0,
        status: "open"
      }
    )
    (var-set next-billing-period (+ billing-period u1))
    (ok billing-period)
  )
)

(define-public (finalize-billing-period (billing-period uint) (total-consumption uint) (total-revenue uint) (facilities-count uint))
  (let ((billing-data (unwrap! (map-get? utility-billing { billing-period: billing-period }) ERR-BILLING-PERIOD-EXISTS)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status billing-data) "open") ERR-BILLING-PERIOD-EXISTS)
    (ok (map-set utility-billing
      { billing-period: billing-period }
      (merge billing-data {
        total-consumption: total-consumption,
        total-revenue: total-revenue,
        facilities-billed: facilities-count,
        status: "closed"
      })
    ))
  )
)

;; Outage Management
(define-public (report-power-outage
  (affected-facilities (list 10 uint))
  (cause (string-ascii 100))
  (estimated-restoration uint)
)
  (let ((outage-id (var-get next-outage-id)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (map-set power-outages
      { outage-id: outage-id }
      {
        affected-facilities: affected-facilities,
        start-time: block-height,
        end-time: none,
        cause: cause,
        estimated-restoration: estimated-restoration,
        status: "active"
      }
    )
    (var-set next-outage-id (+ outage-id u1))
    (ok outage-id)
  )
)

(define-public (resolve-power-outage (outage-id uint))
  (let ((outage-data (unwrap! (map-get? power-outages { outage-id: outage-id }) ERR-OUTAGE-ACTIVE)))
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status outage-data) "active") ERR-OUTAGE-ACTIVE)
    (ok (map-set power-outages
      { outage-id: outage-id }
      (merge outage-data {
        end-time: (some block-height),
        status: "resolved"
      })
    ))
  )
)

;; Infrastructure Management
(define-public (register-grid-component
  (component-type (string-ascii 30))
  (location (string-ascii 100))
  (capacity uint)
)
  (let ((component-id (var-get next-component-id)))
    (asserts! (is-utility-engineer) ERR-NOT-AUTHORIZED)
    (map-set grid-infrastructure
      { component-id: component-id }
      {
        component-type: component-type,
        location: location,
        capacity: capacity,
        status: "operational",
        last-inspection: block-height,
        maintenance-due: (+ block-height u4380) ;; Approximately 6 months
      }
    )
    (var-set next-component-id (+ component-id u1))
    (ok component-id)
  )
)

(define-public (perform-infrastructure-maintenance (component-id uint))
  (let ((component-data (unwrap! (map-get? grid-infrastructure { component-id: component-id }) ERR-INVALID-FACILITY-ID)))
    (asserts! (is-utility-engineer) ERR-NOT-AUTHORIZED)
    (ok (map-set grid-infrastructure
      { component-id: component-id }
      (merge component-data {
        last-inspection: block-height,
        maintenance-due: (+ block-height u4380),
        status: "operational"
      })
    ))
  )
)

;; Load Balancing
(define-public (implement-load-shedding (facilities-to-reduce (list 10 uint)) (reduction-percentage uint))
  (begin
    (asserts! (is-authorized-operator) ERR-NOT-AUTHORIZED)
    (asserts! (<= reduction-percentage u100) ERR-INVALID-CONSUMPTION)
    ;; In a real implementation, this would reduce power to specified facilities
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-electrical-facility (facility-id uint))
  (map-get? electrical-facilities { facility-id: facility-id })
)

(define-read-only (get-power-consumption (facility-id uint) (period uint))
  (map-get? power-consumption { facility-id: facility-id, period: period })
)

(define-read-only (get-billing-period (billing-period uint))
  (map-get? utility-billing { billing-period: billing-period })
)

(define-read-only (get-power-outage (outage-id uint))
  (map-get? power-outages { outage-id: outage-id })
)

(define-read-only (get-grid-component (component-id uint))
  (map-get? grid-infrastructure { component-id: component-id })
)

(define-read-only (get-grid-status)
  {
    total-capacity: (var-get total-capacity),
    current-load: (var-get current-load),
    available-capacity: (- (var-get total-capacity) (var-get current-load)),
    utilization-percentage: (/ (* (var-get current-load) u100) (var-get total-capacity))
  }
)

(define-read-only (facility-needs-maintenance (facility-id uint))
  (match (map-get? electrical-facilities { facility-id: facility-id })
    facility-data (> (- block-height (get last-maintenance facility-data)) u8760) ;; More than 1 year
    false
  )
)
