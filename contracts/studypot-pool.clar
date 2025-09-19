;; StudypotPool - Learning Token Pool Contract
;; Manages collective funding for study resources
;; Members contribute STX tokens to a shared pool

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-already-member (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-withdrawal-failed (err u105))
(define-constant err-transfer-failed (err u106))
(define-constant err-pool-inactive (err u107))
(define-constant minimum-contribution u1000000) ;; 1 STX minimum

;; Data Variables
(define-data-var pool-active bool true)
(define-data-var total-pool-balance uint u0)
(define-data-var total-members uint u0)
(define-data-var pool-creation-height uint u0)

;; Data Maps
(define-map members
  { member: principal }
  {
    contribution: uint,
    joined-height: uint,
    active: bool
  }
)

(define-map member-list
  { index: uint }
  { member: principal }
)

(define-map resource-requests
  { request-id: uint }
  {
    requester: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    cost: uint,
    votes-for: uint,
    votes-against: uint,
    created-height: uint,
    status: (string-ascii 20)
  }
)

(define-data-var next-request-id uint u0)

;; Read-only functions
(define-read-only (get-pool-info)
  {
    active: (var-get pool-active),
    total-balance: (var-get total-pool-balance),
    total-members: (var-get total-members),
    creation-height: (var-get pool-creation-height),
    minimum-contribution: minimum-contribution
  }
)

(define-read-only (get-member-info (member principal))
  (map-get? members { member: member })
)

(define-read-only (is-member (member principal))
  (is-some (map-get? members { member: member }))
)

(define-read-only (get-member-contribution (member principal))
  (default-to u0 
    (get contribution (map-get? members { member: member }))
  )
)

(define-read-only (get-resource-request (request-id uint))
  (map-get? resource-requests { request-id: request-id })
)

(define-read-only (get-next-request-id)
  (var-get next-request-id)
)

;; Private functions
(define-private (is-valid-contribution (amount uint))
  (>= amount minimum-contribution)
)

(define-private (update-total-balance (amount uint) (add bool))
  (if add
    (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
    (var-set total-pool-balance (- (var-get total-pool-balance) amount))
  )
)

;; Public functions
(define-public (join-pool (amount uint))
  (let
    (
      (sender tx-sender)
      (existing-member (map-get? members { member: sender }))
    )
    (asserts! (var-get pool-active) err-pool-inactive)
    (asserts! (is-none existing-member) err-already-member)
    (asserts! (is-valid-contribution amount) err-invalid-amount)
    
    ;; Transfer STX from sender to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Add member to members map
    (map-set members
      { member: sender }
      {
        contribution: amount,
        joined-height: stacks-block-height,
        active: true
      }
    )
    
    ;; Add to member list
    (map-set member-list
      { index: (var-get total-members) }
      { member: sender }
    )
    
    ;; Update totals
    (var-set total-members (+ (var-get total-members) u1))
    (update-total-balance amount true)
    
    (ok true)
  )
)

(define-public (contribute-more (amount uint))
  (let
    (
      (sender tx-sender)
      (member-data (unwrap! (map-get? members { member: sender }) err-not-member))
    )
    (asserts! (var-get pool-active) err-pool-inactive)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Transfer STX from sender to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update member contribution
    (map-set members
      { member: sender }
      (merge member-data { contribution: (+ (get contribution member-data) amount) })
    )
    
    ;; Update total pool balance
    (update-total-balance amount true)
    
    (ok true)
  )
)

(define-public (request-resource (title (string-ascii 100)) (description (string-ascii 500)) (cost uint))
  (let
    (
      (sender tx-sender)
      (current-id (var-get next-request-id))
    )
    (asserts! (var-get pool-active) err-pool-inactive)
    (asserts! (is-some (map-get? members { member: sender })) err-not-member)
    (asserts! (> cost u0) err-invalid-amount)
    (asserts! (<= cost (var-get total-pool-balance)) err-insufficient-funds)
    
    ;; Create resource request
    (map-set resource-requests
      { request-id: current-id }
      {
        requester: sender,
        title: title,
        description: description,
        cost: cost,
        votes-for: u0,
        votes-against: u0,
        created-height: stacks-block-height,
        status: "pending"
      }
    )
    
    ;; Increment request ID counter
    (var-set next-request-id (+ current-id u1))
    
    (ok current-id)
  )
)

(define-public (withdraw-from-pool (amount uint))
  (let
    (
      (sender tx-sender)
      (member-data (unwrap! (map-get? members { member: sender }) err-not-member))
      (member-contribution (get contribution member-data))
    )
    (asserts! (var-get pool-active) err-pool-inactive)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount member-contribution) err-insufficient-funds)
    
    ;; Transfer STX back to member
    (try! (as-contract (stx-transfer? amount tx-sender sender)))
    
    ;; Update member contribution
    (if (is-eq amount member-contribution)
      ;; Complete withdrawal - remove member
      (begin
        (map-delete members { member: sender })
        (var-set total-members (- (var-get total-members) u1))
      )
      ;; Partial withdrawal - update contribution
      (map-set members
        { member: sender }
        (merge member-data { contribution: (- member-contribution amount) })
      )
    )
    
    ;; Update total pool balance
    (update-total-balance amount false)
    
    (ok true)
  )
)

;; Owner-only functions
(define-public (toggle-pool-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set pool-active (not (var-get pool-active)))
    (ok (var-get pool-active))
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get total-pool-balance)) err-insufficient-funds)
    
    ;; Transfer funds to owner
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    
    ;; Update pool balance
    (update-total-balance amount false)
    
    (ok true)
  )
)

