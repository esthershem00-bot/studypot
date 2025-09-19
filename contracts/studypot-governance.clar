;; StudypotGovernance - Voting and Resource Management Contract
;; Handles community voting on resource purchases and governance
;; Works in conjunction with StudypotPool contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-member (err u201))
(define-constant err-already-voted (err u202))
(define-constant err-invalid-proposal (err u203))
(define-constant err-proposal-expired (err u204))
(define-constant err-proposal-not-found (err u205))
(define-constant err-voting-ended (err u206))
(define-constant err-insufficient-votes (err u207))
(define-constant err-proposal-not-approved (err u208))
(define-constant voting-period u144) ;; ~24 hours in blocks
(define-constant min-quorum-percentage u25) ;; 25% minimum participation

;; Data Variables
(define-data-var governance-active bool true)
(define-data-var total-proposals uint u0)
(define-data-var quorum-threshold uint u1) ;; Updated dynamically

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    cost: uint,
    proposer: principal,
    created-height: uint,
    voting-end-height: uint,
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    status: (string-ascii 20),
    executed: bool
  }
)

(define-map member-votes
  { proposal-id: uint, member: principal }
  {
    vote: bool, ;; true = for, false = against
    weight: uint,
    cast-height: uint
  }
)

(define-map governance-settings
  { key: (string-ascii 50) }
  { value: uint }
)

(define-map approved-resources
  { resource-id: uint }
  {
    title: (string-ascii 100),
    cost: uint,
    approved-height: uint,
    purchased: bool,
    purchase-height: (optional uint)
  }
)

(define-data-var next-resource-id uint u0)

;; Read-only functions
(define-read-only (get-governance-info)
  {
    active: (var-get governance-active),
    total-proposals: (var-get total-proposals),
    voting-period: voting-period,
    min-quorum-percentage: min-quorum-percentage,
    quorum-threshold: (var-get quorum-threshold)
  }
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-member-vote (proposal-id uint) (member principal))
  (map-get? member-votes { proposal-id: proposal-id, member: member })
)

(define-read-only (has-voted (proposal-id uint) (member principal))
  (is-some (map-get? member-votes { proposal-id: proposal-id, member: member }))
)

(define-read-only (get-proposal-status (proposal-id uint))
  (let
    (
      (proposal (map-get? proposals { proposal-id: proposal-id }))
    )
    (match proposal
      proposal-data
      (some {
        id: proposal-id,
        title: (get title proposal-data),
        status: (get status proposal-data),
        votes-for: (get votes-for proposal-data),
        votes-against: (get votes-against proposal-data),
        total-voters: (get total-voters proposal-data),
        voting-ends: (get voting-end-height proposal-data),
        current-block: stacks-block-height
      })
      none
    )
  )
)

(define-read-only (get-approved-resource (resource-id uint))
  (map-get? approved-resources { resource-id: resource-id })
)

;; Private functions
(define-private (is-voting-active (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) false))
    )
    (and
      (<= stacks-block-height (get voting-end-height proposal))
      (is-eq (get status proposal) "active")
    )
  )
)

(define-private (calculate-vote-weight (member principal))
  ;; In a real implementation, this would call the pool contract
  ;; For now, we'll use a simple weight of 1 per member
  ;; This could be enhanced to weight by contribution amount
  u1
)

(define-private (update-quorum-threshold (total-members uint))
  (let
    (
      (new-threshold (/ (* total-members min-quorum-percentage) u100))
    )
    (var-set quorum-threshold (if (> new-threshold u1) new-threshold u1))
  )
)

(define-private (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) false))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (total-voters (get total-voters proposal))
      (quorum-met (>= total-voters (var-get quorum-threshold)))
      (approved (and quorum-met (> votes-for votes-against)))
    )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { 
        status: (if approved "approved" "rejected")
      })
    )
    
    ;; If approved, add to approved resources
    (if approved
      (begin
        (map-set approved-resources
          { resource-id: (var-get next-resource-id) }
          {
            title: (get title proposal),
            cost: (get cost proposal),
            approved-height: stacks-block-height,
            purchased: false,
            purchase-height: none
          }
        )
        (var-set next-resource-id (+ (var-get next-resource-id) u1))
      )
      false
    )
    
    approved
  )
)

;; Public functions
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (cost uint))
  (let
    (
      (sender tx-sender)
      (proposal-id (var-get total-proposals))
      (voting-end (+ stacks-block-height voting-period))
    )
    (asserts! (var-get governance-active) (err u209))
    ;; In a real implementation, verify sender is a pool member
    (asserts! (> cost u0) err-invalid-proposal)
    
    ;; Create the proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        cost: cost,
        proposer: sender,
        created-height: stacks-block-height,
        voting-end-height: voting-end,
        votes-for: u0,
        votes-against: u0,
        total-voters: u0,
        status: "active",
        executed: false
      }
    )
    
    ;; Increment proposal counter
    (var-set total-proposals (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (sender tx-sender)
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
      (vote-weight (calculate-vote-weight sender))
    )
    (asserts! (var-get governance-active) (err u209))
    (asserts! (is-voting-active proposal-id) err-voting-ended)
    (asserts! (not (has-voted proposal-id sender)) err-already-voted)
    
    ;; Record the vote
    (map-set member-votes
      { proposal-id: proposal-id, member: sender }
      {
        vote: vote,
        weight: vote-weight,
        cast-height: stacks-block-height
      }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote 
                     (+ (get votes-for proposal) vote-weight)
                     (get votes-for proposal)),
        votes-against: (if vote
                         (get votes-against proposal)
                         (+ (get votes-against proposal) vote-weight)),
        total-voters: (+ (get total-voters proposal) u1)
      })
    )
    
    (ok true)
  )
)

(define-public (finalize-voting (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
    )
    (asserts! (var-get governance-active) (err u209))
    (asserts! (> stacks-block-height (get voting-end-height proposal)) err-voting-ended)
    (asserts! (is-eq (get status proposal) "active") err-invalid-proposal)
    
    (ok (finalize-proposal proposal-id))
  )
)

(define-public (execute-approved-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
    )
    (asserts! (var-get governance-active) (err u209))
    (asserts! (is-eq (get status proposal) "approved") err-proposal-not-approved)
    (asserts! (not (get executed proposal)) err-invalid-proposal)
    
    ;; Mark as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    ;; In a real implementation, this would interact with the pool contract
    ;; to transfer funds for the resource purchase
    
    (ok true)
  )
)

(define-public (mark-resource-purchased (resource-id uint))
  (let
    (
      (resource (unwrap! (map-get? approved-resources { resource-id: resource-id }) err-proposal-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get purchased resource)) err-invalid-proposal)
    
    (map-set approved-resources
      { resource-id: resource-id }
      (merge resource {
        purchased: true,
        purchase-height: (some stacks-block-height)
      })
    )
    
    (ok true)
  )
)

;; Owner-only functions
(define-public (toggle-governance-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set governance-active (not (var-get governance-active)))
    (ok (var-get governance-active))
  )
)

(define-public (update-governance-setting (key (string-ascii 50)) (value uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set governance-settings { key: key } { value: value })
    (ok true)
  )
)

