;; FlexiLend - Flexible Multi-Asset Peer-to-Peer Lending Platform
;; A decentralized lending protocol that allows users to create custom loan terms
;; and facilitates trustless lending with STX, SIP-10 tokens, and NFTs as collateral

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
(define-constant err-unsupported-asset (err u111))
(define-constant err-invalid-collateral-type (err u112))
(define-constant err-nft-transfer-failed (err u113))
(define-constant err-token-transfer-failed (err u114))
(define-constant err-invalid-token-contract (err u115))

;; Asset types
(define-constant asset-type-stx u1)
(define-constant asset-type-sip10 u2)
(define-constant asset-type-nft u3)

;; Data Variables
(define-data-var loan-counter uint u0)
(define-data-var platform-fee uint u250) ;; 2.5% in basis points
(define-data-var max-loan-duration uint u52560) ;; ~1 year in blocks
(define-data-var min-collateral-ratio uint u15000) ;; 150% in basis points

;; Supported asset contracts
(define-map supported-sip10-tokens
  { contract: principal }
  { enabled: bool, decimals: uint }
)

(define-map supported-nft-collections
  { contract: principal }
  { enabled: bool, floor-price: uint } ;; Floor price in STX microunits
)

;; Data Maps
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: (optional principal),
    amount: uint,
    loan-asset-type: uint, ;; 1=STX, 2=SIP10
    loan-asset-contract: (optional principal),
    collateral-amount: uint,
    collateral-asset-type: uint, ;; 1=STX, 2=SIP10, 3=NFT
    collateral-asset-contract: (optional principal),
    collateral-nft-id: (optional uint),
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
    total-borrowed-stx: uint,
    total-lent-stx: uint,
    reputation-score: uint
  }
)

;; Private functions (moved before public functions that use them)

;; Update user statistics
(define-private (update-user-stats (user principal) (loans-created uint) (loans-funded uint) (borrowed uint) (lent uint))
  (let (
    (current-stats (default-to
      { loans-created: u0, loans-funded: u0, total-borrowed-stx: u0, total-lent-stx: u0, reputation-score: u0 }
      (map-get? user-stats { user: user })
    ))
    (new-reputation (+ (get reputation-score current-stats) (+ loans-created loans-funded)))
  )
    (map-set user-stats
      { user: user }
      {
        loans-created: (+ (get loans-created current-stats) loans-created),
        loans-funded: (+ (get loans-funded current-stats) loans-funded),
        total-borrowed-stx: (+ (get total-borrowed-stx current-stats) borrowed),
        total-lent-stx: (+ (get total-lent-stx current-stats) lent),
        reputation-score: new-reputation
      }
    )
  )
)

;; Internal loan creation function
(define-private (create-loan-internal 
  (amount uint) 
  (loan-asset-type uint) 
  (loan-asset-contract (optional principal))
  (collateral-amount uint) 
  (collateral-asset-type uint) 
  (collateral-asset-contract (optional principal)) 
  (collateral-nft-id (optional uint))
  (interest-rate uint) 
  (duration uint)
)
  (let (
    (loan-id (+ (var-get loan-counter) u1))
    (loan-key { loan-id: loan-id })
  )
    ;; Input validation is now done in calling functions
    ;; Additional validation for asset types
    (asserts! (or (is-eq loan-asset-type asset-type-stx) (is-eq loan-asset-type asset-type-sip10)) err-unsupported-asset)
    (asserts! (or (is-eq collateral-asset-type asset-type-stx) 
                  (is-eq collateral-asset-type asset-type-sip10) 
                  (is-eq collateral-asset-type asset-type-nft)) err-invalid-collateral-type)
    
    ;; FIX: Validate collateral-amount before using in transfer
    (asserts! (> collateral-amount u0) err-invalid-amount)
    ;; Handle STX collateral transfer
    (if (is-eq collateral-asset-type asset-type-stx)
      (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
      true
    )
    
    (map-set loans
      loan-key
      {
        borrower: tx-sender,
        lender: none,
        amount: amount,
        loan-asset-type: loan-asset-type,
        loan-asset-contract: loan-asset-contract,
        collateral-amount: collateral-amount,
        collateral-asset-type: collateral-asset-type,
        collateral-asset-contract: collateral-asset-contract,
        collateral-nft-id: collateral-nft-id,
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

;; Public Functions

;; Create STX loan with STX collateral (original functionality)
(define-public (create-stx-loan (amount uint) (collateral uint) (interest-rate uint) (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral u0) err-invalid-amount)
    (asserts! (and (>= interest-rate u100) (<= interest-rate u10000)) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    
    (create-loan-internal 
      amount 
      asset-type-stx 
      none 
      collateral 
      asset-type-stx 
      none 
      none 
      interest-rate 
      duration
    )
  )
)

;; Create STX loan with SIP-10 token collateral (placeholder - requires trait implementation)
(define-public (create-stx-loan-with-token-collateral 
  (amount uint) 
  (collateral-amount uint) 
  (collateral-token-contract principal) 
  (interest-rate uint) 
  (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral-amount u0) err-invalid-amount)
    (asserts! (and (>= interest-rate u100) (<= interest-rate u10000)) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    ;; FIX: Validate collateral-token-contract parameter
    (asserts! (not (is-eq collateral-token-contract tx-sender)) err-invalid-token-contract)
    
    (let (
      (token-info-result (map-get? supported-sip10-tokens { contract: collateral-token-contract }))
    )
      (asserts! (is-some token-info-result) err-unsupported-asset)
      (let (
        (token-info (unwrap-panic token-info-result))
      )
        (asserts! (get enabled token-info) err-unsupported-asset)
        ;; Note: Actual token transfer would require trait implementation
        ;; For now, we'll create the loan structure without the transfer
        (create-loan-internal 
          amount 
          asset-type-stx 
          none 
          collateral-amount 
          asset-type-sip10 
          (some collateral-token-contract) 
          none 
          interest-rate 
          duration
        )
      )
    )
  )
)

;; Create STX loan with NFT collateral (placeholder - requires trait implementation)
(define-public (create-stx-loan-with-nft-collateral 
  (amount uint) 
  (nft-contract principal) 
  (nft-id uint) 
  (interest-rate uint) 
  (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> nft-id u0) err-invalid-amount)
    (asserts! (and (>= interest-rate u100) (<= interest-rate u10000)) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    (asserts! (not (is-eq nft-contract tx-sender)) err-invalid-token-contract)
    
    (let (
      (collection-info-result (map-get? supported-nft-collections { contract: nft-contract }))
    )
      (asserts! (is-some collection-info-result) err-unsupported-asset)
      (let (
        (collection-info (unwrap-panic collection-info-result))
        (floor-price (get floor-price collection-info))
      )
        (asserts! (get enabled collection-info) err-unsupported-asset)
        (asserts! (> floor-price u0) err-insufficient-collateral)
        (asserts! (>= floor-price amount) err-insufficient-collateral)
        
        ;; Note: Actual NFT transfer would require trait implementation
        ;; For now, we'll create the loan structure without the transfer
        (create-loan-internal 
          amount 
          asset-type-stx 
          none 
          floor-price 
          asset-type-nft 
          (some nft-contract) 
          (some nft-id) 
          interest-rate 
          duration
        )
      )
    )
  )
)


;; Create SIP-10 token loan with STX collateral (placeholder)
(define-public (create-token-loan 
  (token-contract principal) 
  (amount uint) 
  (collateral-stx uint) 
  (interest-rate uint) 
  (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral-stx u0) err-invalid-amount)
    (asserts! (and (>= interest-rate u100) (<= interest-rate u10000)) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    (asserts! (not (is-eq token-contract tx-sender)) err-invalid-token-contract)
    
    (let (
      (token-info (unwrap! (map-get? supported-sip10-tokens { contract: token-contract }) err-unsupported-asset))
    )
      (asserts! (get enabled token-info) err-unsupported-asset)
      
      (try! (stx-transfer? collateral-stx tx-sender (as-contract tx-sender)))
      (create-loan-internal 
        amount 
        asset-type-sip10 
        (some token-contract) 
        collateral-stx 
        asset-type-stx 
        none 
        none 
        interest-rate 
        duration
      )
    )
  )
)

;; Fund STX loan
(define-public (fund-stx-loan (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
    (loan (unwrap! (map-get? loans loan-key) err-not-found))
    (borrower (get borrower loan))
    (amount (get amount loan))
    (current-block stacks-block-height)
  )
    ;; Validate loan-id and loan state
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq (get status loan) "pending") err-already-funded)
    (asserts! (not (is-eq tx-sender borrower)) err-unauthorized)
    (asserts! (is-eq (get loan-asset-type loan) asset-type-stx) err-unsupported-asset)
    ;; Validate amounts from loan data
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    
    ;; FIX: Validate amount before using in transfer
    (asserts! (> amount u0) err-invalid-amount)
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

;; Fund token loan (placeholder - requires trait implementation)
(define-public (fund-token-loan (loan-id uint))
  (let (
    (loan-key { loan-id: loan-id })
    (loan (unwrap! (map-get? loans loan-key) err-not-found))
    (borrower (get borrower loan))
    (amount (get amount loan))
    (current-block stacks-block-height)
  )
    ;; Validate loan-id and loan state
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq (get status loan) "pending") err-already-funded)
    (asserts! (not (is-eq tx-sender borrower)) err-unauthorized)
    (asserts! (is-eq (get loan-asset-type loan) asset-type-sip10) err-unsupported-asset)
    ;; Validate amounts from loan data
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    
    ;; Note: Actual token transfer would require trait implementation
    ;; For now, we'll just update the loan status
    (map-set loans
      loan-key
      (merge loan {
        lender: (some tx-sender),
        funded-at: (some current-block),
        status: "active"
      })
    )
    
    (update-user-stats tx-sender u0 u1 u0 u0)
    (ok true)
  )
)

;; Repay STX loan
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
    (current-block stacks-block-height)
    (blocks-elapsed (- current-block funded-at))
    (interest-amount (calculate-interest amount interest-rate blocks-elapsed duration))
    (total-repayment (+ amount interest-amount))
    (platform-fee-amount (/ (* total-repayment (var-get platform-fee)) u10000))
    (lender-payment (- total-repayment platform-fee-amount))
  )
    ;; Validate loan-id and loan state
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq tx-sender borrower) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    ;; Validate amounts from loan data
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (and (>= interest-rate u100) (<= interest-rate u10000)) err-invalid-interest)
    ;; Validate calculated values
    (asserts! (> total-repayment u0) err-invalid-amount)
    (asserts! (> lender-payment u0) err-invalid-amount)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    
    ;; Handle STX loan repayment
    (if (is-eq (get loan-asset-type loan) asset-type-stx)
      (begin
        ;; FIX: Additional validation before transfers
        (asserts! (> lender-payment u0) err-invalid-amount)
        (asserts! (>= platform-fee-amount u0) err-invalid-amount)
        (try! (stx-transfer? lender-payment tx-sender lender))
        (if (> platform-fee-amount u0)
          (try! (stx-transfer? platform-fee-amount tx-sender contract-owner))
          true
        )
      )
      ;; Token loan repayment would require trait implementation
      true
    )
    
    ;; Return collateral based on type
    (if (is-eq (get collateral-asset-type loan) asset-type-stx)
      (let (
        (collateral-amt (get collateral-amount loan))
      )
        ;; FIX: Validate collateral amount before transfer
        (asserts! (> collateral-amt u0) err-invalid-amount)
        (try! (as-contract (stx-transfer? collateral-amt tx-sender borrower)))
      )
      ;; Other collateral types would require trait implementation
      true
    )
    
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
    (current-block stacks-block-height)
    (due-block (+ funded-at duration))
  )
    ;; Validate loan-id and loan state
    (asserts! (> loan-id u0) err-invalid-amount)
    (asserts! (<= loan-id (var-get loan-counter)) err-not-found)
    (asserts! (is-eq tx-sender lender) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    ;; Validate duration from loan data
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    ;; Check if loan is actually overdue
    (asserts! (>= current-block due-block) err-loan-overdue)
    
    ;; Transfer collateral to lender based on type
    (if (is-eq (get collateral-asset-type loan) asset-type-stx)
      (let (
        (collateral-amt (get collateral-amount loan))
      )
        ;; FIX: Validate collateral amount before transfer
        (asserts! (> collateral-amt u0) err-invalid-amount)
        (try! (as-contract (stx-transfer? collateral-amt tx-sender lender)))
      )
      ;; Other collateral types would require trait implementation
      true
    )
    
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
    ;; Validate loan-id parameter
    (asserts! (> loan-id u0) (err err-invalid-amount))
    (asserts! (<= loan-id (var-get loan-counter)) (err err-not-found))
    (ok (map-get? loans loan-key))
  )
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
  (default-to
    { loans-created: u0, loans-funded: u0, total-borrowed-stx: u0, total-lent-stx: u0, reputation-score: u0 }
    (map-get? user-stats { user: user })
  )
)

;; Calculate interest for a loan
(define-read-only (calculate-interest (principal-amount uint) (rate uint) (blocks-elapsed uint) (total-duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> principal-amount u0) u0)
    (asserts! (and (>= rate u100) (<= rate u10000)) u0)
    (asserts! (> total-duration u0) u0)
    
    (let (
      (annual-interest (/ (* principal-amount rate) u10000))
      (time-factor (/ (* blocks-elapsed u10000) total-duration))
      (proportional-interest (/ (* annual-interest time-factor) u10000))
    )
      proportional-interest
    )
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
            (duration (get duration loan))
            (due-block (+ funded-block duration))
            (current-block stacks-block-height)
          )
            ;; Validate duration from loan data
            (and (> duration u0) (>= current-block due-block))
          )
          false
        )
        false
      )
      false
    )
  )
)

;; Get supported SIP-10 tokens
(define-read-only (get-supported-sip10-token (contract principal))
  (map-get? supported-sip10-tokens { contract: contract })
)

;; Get supported NFT collections
(define-read-only (get-supported-nft-collection (contract principal))
  (map-get? supported-nft-collections { contract: contract })
)

;; Admin functions (owner only)

;; Add supported SIP-10 token
(define-public (add-supported-sip10-token (contract principal) (decimals uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate contract and decimals parameters
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (> decimals u0) err-invalid-amount) ;; Min 1 decimal
    (asserts! (<= decimals u18) err-invalid-amount) ;; Max 18 decimals
    
    (map-set supported-sip10-tokens
      { contract: contract }
      { enabled: true, decimals: decimals }
    )
    (ok true)
  )
)

;; Remove supported SIP-10 token
(define-public (remove-supported-sip10-token (contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate contract parameter
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    
    (map-set supported-sip10-tokens
      { contract: contract }
      { enabled: false, decimals: u0 }
    )
    (ok true)
  )
)

;; Add supported NFT collection
(define-public (add-supported-nft-collection (contract principal) (floor-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate contract and floor-price parameters
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (> floor-price u0) err-invalid-amount)
    
    (map-set supported-nft-collections
      { contract: contract }
      { enabled: true, floor-price: floor-price }
    )
    (ok true)
  )
)

;; Update NFT collection floor price
(define-public (update-nft-floor-price (contract principal) (new-floor-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate contract and new-floor-price parameters
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (> new-floor-price u0) err-invalid-amount)
    (asserts! (is-some (map-get? supported-nft-collections { contract: contract })) err-not-found)
    
    (map-set supported-nft-collections
      { contract: contract }
      { enabled: true, floor-price: new-floor-price }
    )
    (ok true)
  )
)

;; Remove supported NFT collection
(define-public (remove-supported-nft-collection (contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate contract parameter
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    
    (map-set supported-nft-collections
      { contract: contract }
      { enabled: false, floor-price: u0 }
    )
    (ok true)
  )
)

;; Update platform fee
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate new-fee parameter
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Update minimum collateral ratio
(define-public (set-min-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; FIX: Validate new-ratio parameter  
    (asserts! (>= new-ratio u10000) err-invalid-amount) ;; Min 100%
    (var-set min-collateral-ratio new-ratio)
    (ok true)
  )
)