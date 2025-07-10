;; FlexiLend - Flexible Peer-to-Peer Lending Platform
;; A decentralized lending protocol that allows users to create custom loan terms
;; and facilitates trustless lending with collateral management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-loan-not-active (err u104))
(define-constant err-loan-not-funded (err u105))
(define-constant err-insufficient-collateral (err u106))
(define-constant err-loan-overdue (err u107))
(define-constant err-already-funded (err u108))
(define-constant err-invalid-duration (err u109))
(define-constant err-invalid-interest (err u110))

;; Data Variables
(define-data-var loan-counter uint u0)
(define-data-var platform-fee uint u250) ;; 2.5% in basis points
(define-data-var max-loan-duration uint u52560) ;; ~1 year in blocks
(define-data-var min-collateral-ratio uint u15000) ;; 150% in basis points

;; Data Maps
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: (optional principal),
    amount: uint,
    collateral: uint,
    interest-rate: uint, ;; basis points per year
    duration: uint, ;; blocks
    funded-at: (optional uint),
    repaid-at: (optional uint),
    status: (string-ascii 20)
  }
)

(define-map user-stats
  { user: principal }
  {
    loans-created: uint,
    loans-funded: uint,
    total-borrowed: uint,
    total-lent: uint,
    reputation-score: uint
  }
)

;; Public Functions

;; Create a new loan request
(define-public (create-loan (amount uint) (collateral uint) (interest-rate uint) (duration uint))
  (let (
    (loan-id (+ (var-get loan-counter) u1))
    (collateral-ratio (/ (* collateral u10000) amount))
    (loan-key { loan-id: loan-id })
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral u0) err-invalid-amount)
    (asserts! (>= collateral-ratio (var-get min-collateral-ratio)) err-insufficient-collateral)
    (asserts! (and (>= interest-rate u100) (<= interest-rate u10000)) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    
    (try! (stx-transfer? collateral tx-sender (as-contract tx-sender)))
    
    (map-set loans
      loan-key
      {
        borrower: tx-sender,
        lender: none,
        amount: amount,
        collateral: collateral,
        interest-rate: interest-rate,
        duration: duration,
        funded-at: none,
        repaid-at: none,
        status: "pending"
      }
    )
    
    (update-user-stats tx-sender u1 u0 u0 u0)
    (var-set loan-counter loan-id)
    (ok loan-id)
  )
)

;; Fund a loan
(define-public (fund-loan (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
    (loan (unwrap! (map-get? loans loan-key) err-not-found))
    (borrower (get borrower loan))
    (amount (get amount loan))
    (current-block stacks-block-height)
  )
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq (get status loan) "pending") err-already-funded)
    (asserts! (not (is-eq tx-sender borrower)) err-unauthorized)
    
    (try! (stx-transfer? amount tx-sender borrower))
    
    (map-set loans
      loan-key
      (merge loan {
        lender: (some tx-sender),
        funded-at: (some current-block),
        status: "active"
      })
    )
    
    (update-user-stats tx-sender u0 u1 u0 amount)
    (ok true)
  )
)

;; Repay a loan
(define-public (repay-loan (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
    (loan (unwrap! (map-get? loans loan-key) err-not-found))
    (borrower (get borrower loan))
    (lender (unwrap! (get lender loan) err-loan-not-funded))
    (amount (get amount loan))
    (interest-rate (get interest-rate loan))
    (duration (get duration loan))
    (funded-at (unwrap! (get funded-at loan) err-loan-not-funded))
    (collateral (get collateral loan))
    (current-block stacks-block-height)
    (blocks-elapsed (- current-block funded-at))
    (interest-amount (calculate-interest amount interest-rate blocks-elapsed duration))
    (total-repayment (+ amount interest-amount))
    (platform-fee-amount (/ (* total-repayment (var-get platform-fee)) u10000))
    (lender-payment (- total-repayment platform-fee-amount))
  )
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq tx-sender borrower) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    
    (try! (stx-transfer? lender-payment tx-sender lender))
    (try! (stx-transfer? platform-fee-amount tx-sender contract-owner))
    (try! (as-contract (stx-transfer? collateral tx-sender borrower)))
    
    (map-set loans
      loan-key
      (merge loan {
        repaid-at: (some current-block),
        status: "repaid"
      })
    )
    
    (update-user-stats borrower u0 u0 amount u0)
    (ok total-repayment)
  )
)

;; Liquidate overdue loan
(define-public (liquidate-loan (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
    (loan (unwrap! (map-get? loans loan-key) err-not-found))
    (lender (unwrap! (get lender loan) err-loan-not-funded))
    (funded-at (unwrap! (get funded-at loan) err-loan-not-funded))
    (duration (get duration loan))
    (collateral (get collateral loan))
    (current-block stacks-block-height)
    (due-block (+ funded-at duration))
  )
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq tx-sender lender) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    (asserts! (>= current-block due-block) err-loan-overdue)
    
    (try! (as-contract (stx-transfer? collateral tx-sender lender)))
    
    (map-set loans
      loan-key
      (merge loan {
        status: "liquidated"
      })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get loan details
(define-read-only (get-loan (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
  )
    (asserts! (> loan-id u0) (err err-invalid-amount))
    (asserts! (<= loan-id (var-get loan-counter)) (err err-not-found))
    (ok (map-get? loans loan-key))
  )
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
  (default-to
    { loans-created: u0, loans-funded: u0, total-borrowed: u0, total-lent: u0, reputation-score: u0 }
    (map-get? user-stats { user: user })
  )
)

;; Calculate interest for a loan
(define-read-only (calculate-interest (principal uint) (rate uint) (blocks-elapsed uint) (total-duration uint))
  (let (
    (annual-interest (/ (* principal rate) u10000))
    (blocks-per-year u52560) ;; Approximate blocks per year
    (time-factor (/ (* blocks-elapsed u10000) total-duration))
    (proportional-interest (/ (* annual-interest time-factor) u10000))
  )
    proportional-interest
  )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    total-loans: (var-get loan-counter),
    platform-fee: (var-get platform-fee),
    max-duration: (var-get max-loan-duration),
    min-collateral-ratio: (var-get min-collateral-ratio)
  }
)

;; Check if loan is overdue
(define-read-only (is-loan-overdue (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
  )
    (if (and (> loan-id u0) (<= loan-id (var-get loan-counter)))
      (match (map-get? loans loan-key)
        loan
        (match (get funded-at loan)
          funded-block
          (let (
            (due-block (+ funded-block (get duration loan)))
            (current-block stacks-block-height)
          )
            (>= current-block due-block)
          )
          false
        )
        false
      )
      false
    )
  )
)

;; Private functions

;; Update user statistics
(define-private (update-user-stats (user principal) (loans-created uint) (loans-funded uint) (borrowed uint) (lent uint))
  (let (
    (current-stats (default-to
      { loans-created: u0, loans-funded: u0, total-borrowed: u0, total-lent: u0, reputation-score: u0 }
      (map-get? user-stats { user: user })
    ))
    (new-reputation (+ (get reputation-score current-stats) (+ loans-created loans-funded)))
  )
    (map-set user-stats
      { user: user }
      {
        loans-created: (+ (get loans-created current-stats) loans-created),
        loans-funded: (+ (get loans-funded current-stats) loans-funded),
        total-borrowed: (+ (get total-borrowed current-stats) borrowed),
        total-lent: (+ (get total-lent current-stats) lent),
        reputation-score: new-reputation
      }
    )
  )
)

;; Admin functions (owner only)

;; Update platform fee
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Update minimum collateral ratio
(define-public (set-min-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= new-ratio u10000) err-invalid-amount) ;; Min 100%
    (var-set min-collateral-ratio new-ratio)
    (ok true)
  )
)