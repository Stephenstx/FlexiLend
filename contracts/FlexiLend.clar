;; FlexiLend - Flexible Multi-Asset Peer-to-Peer Lending Platform
;; A decentralized lending protocol that allows users to create custom loan terms
;; and facilitates trustless lending with STX, SIP-10 tokens, and NFTs as collateral
;; Now with Dynamic Interest Rates based on supply/demand and risk assessment

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
(define-constant err-invalid-risk-score (err u116))

;; Asset types
(define-constant asset-type-stx u1)
(define-constant asset-type-sip10 u2)
(define-constant asset-type-nft u3)

;; Risk assessment constants
(define-constant risk-score-safe u1)
(define-constant risk-score-low u2)
(define-constant risk-score-medium u3)
(define-constant risk-score-high u4)
(define-constant risk-score-very-high u5)

;; Data Variables
(define-data-var loan-counter uint u0)
(define-data-var platform-fee uint u250) ;; 2.5% in basis points
(define-data-var max-loan-duration uint u52560) ;; ~1 year in blocks
(define-data-var min-collateral-ratio uint u15000) ;; 150% in basis points

;; Dynamic interest rate parameters
(define-data-var base-interest-rate uint u500) ;; 5% base rate in basis points
(define-data-var utilization-multiplier uint u200) ;; 2% multiplier for utilization impact
(define-data-var risk-multiplier uint u100) ;; 1% multiplier for risk impact
(define-data-var max-dynamic-rate uint u2000) ;; 20% maximum dynamic rate
(define-data-var min-dynamic-rate uint u100) ;; 1% minimum dynamic rate

;; Supply and demand tracking
(define-data-var total-supply-stx uint u0)
(define-data-var total-demand-stx uint u0)
(define-data-var total-active-loans uint u0)

;; Supported asset contracts
(define-map supported-sip10-tokens
  { contract: principal }
  { enabled: bool, decimals: uint, supply: uint, demand: uint }
)

(define-map supported-nft-collections
  { contract: principal }
  { enabled: bool, floor-price: uint, risk-score: uint } ;; Added risk-score
)

;; Asset utilization tracking
(define-map asset-utilization
  { asset-type: uint, contract: (optional principal) }
  { total-supplied: uint, total-borrowed: uint, active-loans: uint }
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
    status: (string-ascii 20),
    risk-score: uint, ;; Added risk assessment
    dynamic-rate: uint ;; Applied dynamic interest rate
  }
)

(define-map user-stats
  { user: principal }
  {
    loans-created: uint,
    loans-funded: uint,
    total-borrowed-stx: uint,
    total-lent-stx: uint,
    reputation-score: uint,
    default-count: uint ;; Track defaults for risk assessment
  }
)

;; Private functions

;; Calculate risk score based on user history and collateral type
(define-private (calculate-risk-score (user principal) (collateral-type uint) (collateral-contract (optional principal)))
  (let (
    (user-stats-data (get-user-stats user))
    (reputation (get reputation-score user-stats-data))
    (defaults (get default-count user-stats-data))
    (loans-created (get loans-created user-stats-data))
  )
    ;; Base risk calculation
    (if (is-eq loans-created u0)
      risk-score-medium ;; New users get medium risk
      (if (> defaults u0)
        (if (> defaults u2)
          risk-score-very-high ;; Multiple defaults
          risk-score-high ;; Single default
        )
        (if (>= reputation u10)
          risk-score-safe ;; High reputation, no defaults
          (if (>= reputation u5)
            risk-score-low ;; Medium reputation
            risk-score-medium ;; Low reputation
          )
        )
      )
    )
  )
)

;; Calculate utilization rate for an asset
(define-private (calculate-utilization-rate (asset-type uint) (asset-contract (optional principal)))
  (let (
    (utilization-key { asset-type: asset-type, contract: asset-contract })
    (utilization-data (default-to 
      { total-supplied: u0, total-borrowed: u0, active-loans: u0 }
      (map-get? asset-utilization utilization-key)
    ))
    (supplied (get total-supplied utilization-data))
    (borrowed (get total-borrowed utilization-data))
  )
    (if (is-eq supplied u0)
      u0 ;; No supply means 0% utilization
      (/ (* borrowed u10000) supplied) ;; Return in basis points
    )
  )
)

;; Calculate dynamic interest rate
(define-private (calculate-dynamic-interest-rate 
  (base-rate uint) 
  (asset-type uint) 
  (asset-contract (optional principal)) 
  (risk-score uint)
  (collateral-ratio uint)
)
  (let (
    (utilization-rate (calculate-utilization-rate asset-type asset-contract))
    (utilization-adjustment (/ (* utilization-rate (var-get utilization-multiplier)) u10000))
    (risk-adjustment (/ (* risk-score (var-get risk-multiplier)) u1))
    (collateral-adjustment (if (>= collateral-ratio u20000) ;; 200%+ collateral gets discount
      (- u0 u50) ;; 0.5% discount
      u0
    ))
    (calculated-rate (+ (+ base-rate utilization-adjustment) (+ risk-adjustment collateral-adjustment)))
  )
    ;; Ensure rate is within bounds
    (if (> calculated-rate (var-get max-dynamic-rate))
      (var-get max-dynamic-rate)
      (if (< calculated-rate (var-get min-dynamic-rate))
        (var-get min-dynamic-rate)
        calculated-rate
      )
    )
  )
)

;; Update asset utilization
(define-private (update-asset-utilization 
  (asset-type uint) 
  (asset-contract (optional principal))
  (supplied-delta uint)
  (borrowed-delta uint)
  (loan-delta uint)
  (is-addition bool)
)
  (let (
    (utilization-key { asset-type: asset-type, contract: asset-contract })
    (current-data (default-to 
      { total-supplied: u0, total-borrowed: u0, active-loans: u0 }
      (map-get? asset-utilization utilization-key)
    ))
  )
    (map-set asset-utilization
      utilization-key
      {
        total-supplied: (if is-addition 
          (+ (get total-supplied current-data) supplied-delta)
          (if (>= (get total-supplied current-data) supplied-delta)
            (- (get total-supplied current-data) supplied-delta)
            u0
          )
        ),
        total-borrowed: (if is-addition
          (+ (get total-borrowed current-data) borrowed-delta)
          (if (>= (get total-borrowed current-data) borrowed-delta)
            (- (get total-borrowed current-data) borrowed-delta)
            u0
          )
        ),
        active-loans: (if is-addition
          (+ (get active-loans current-data) loan-delta)
          (if (>= (get active-loans current-data) loan-delta)
            (- (get active-loans current-data) loan-delta)
            u0
          )
        )
      }
    )
  )
)

;; Update user statistics
(define-private (update-user-stats (user principal) (loans-created uint) (loans-funded uint) (borrowed uint) (lent uint))
  (let (
    (current-stats (default-to
      { loans-created: u0, loans-funded: u0, total-borrowed-stx: u0, total-lent-stx: u0, reputation-score: u0, default-count: u0 }
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
        reputation-score: new-reputation,
        default-count: (get default-count current-stats)
      }
    )
  )
)

;; Internal loan creation function with dynamic rates
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
    (collateral-ratio (if (> amount u0) (/ (* collateral-amount u10000) amount) u0))
    (risk-score (calculate-risk-score tx-sender collateral-asset-type collateral-asset-contract))
    (dynamic-rate (calculate-dynamic-interest-rate 
      (var-get base-interest-rate) 
      loan-asset-type 
      loan-asset-contract 
      risk-score
      collateral-ratio
    ))
    (final-rate (if (> interest-rate u0) interest-rate dynamic-rate)) ;; Use provided rate or dynamic rate
  )
    ;; Input validation
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral-amount u0) err-invalid-amount)
    (asserts! (and (>= final-rate (var-get min-dynamic-rate)) (<= final-rate (var-get max-dynamic-rate))) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    (asserts! (>= collateral-ratio (var-get min-collateral-ratio)) err-insufficient-collateral)
    (asserts! (and (>= risk-score risk-score-safe) (<= risk-score risk-score-very-high)) err-invalid-risk-score)
    
    ;; Additional validation for asset types
    (asserts! (or (is-eq loan-asset-type asset-type-stx) (is-eq loan-asset-type asset-type-sip10)) err-unsupported-asset)
    (asserts! (or (is-eq collateral-asset-type asset-type-stx) 
                  (is-eq collateral-asset-type asset-type-sip10) 
                  (is-eq collateral-asset-type asset-type-nft)) err-invalid-collateral-type)
    
    ;; Handle STX collateral transfer
    (if (is-eq collateral-asset-type asset-type-stx)
      (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
      true
    )
    
    ;; Update demand tracking
    (update-asset-utilization loan-asset-type loan-asset-contract u0 amount u1 true)
    
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
        interest-rate: final-rate,
        duration: duration,
        funded-at: none,
        repaid-at: none,
        status: "pending",
        risk-score: risk-score,
        dynamic-rate: dynamic-rate
      }
    )
    
    (update-user-stats tx-sender u1 u0 u0 u0)
    (var-set loan-counter loan-id)
    (ok loan-id)
  )
)

;; Public Functions

;; Create STX loan with dynamic interest rates
(define-public (create-stx-loan (amount uint) (collateral uint) (max-interest-rate uint) (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral u0) err-invalid-amount)
    (asserts! (and (>= max-interest-rate (var-get min-dynamic-rate)) (<= max-interest-rate (var-get max-dynamic-rate))) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    
    ;; Calculate dynamic rate and ensure it doesn't exceed max
    (let (
      (collateral-ratio (/ (* collateral u10000) amount))
      (risk-score (calculate-risk-score tx-sender asset-type-stx none))
      (dynamic-rate (calculate-dynamic-interest-rate 
        (var-get base-interest-rate) 
        asset-type-stx 
        none 
        risk-score
        collateral-ratio
      ))
    )
      (asserts! (<= dynamic-rate max-interest-rate) err-invalid-interest)
      (create-loan-internal 
        amount 
        asset-type-stx 
        none 
        collateral 
        asset-type-stx 
        none 
        none 
        u0 ;; Use dynamic rate
        duration
      )
    )
  )
)

;; Create STX loan with SIP-10 token collateral
(define-public (create-stx-loan-with-token-collateral 
  (amount uint) 
  (collateral-amount uint) 
  (collateral-token-contract principal) 
  (max-interest-rate uint) 
  (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral-amount u0) err-invalid-amount)
    (asserts! (and (>= max-interest-rate (var-get min-dynamic-rate)) (<= max-interest-rate (var-get max-dynamic-rate))) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    (asserts! (not (is-eq collateral-token-contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq collateral-token-contract (as-contract tx-sender))) err-invalid-token-contract)
    
    (let (
      (token-info-result (map-get? supported-sip10-tokens { contract: collateral-token-contract }))
    )
      (asserts! (is-some token-info-result) err-unsupported-asset)
      (let (
        (token-info (unwrap! token-info-result err-unsupported-asset))
        (collateral-ratio (/ (* collateral-amount u10000) amount))
        (risk-score (calculate-risk-score tx-sender asset-type-sip10 (some collateral-token-contract)))
        (dynamic-rate (calculate-dynamic-interest-rate 
          (var-get base-interest-rate) 
          asset-type-stx 
          none 
          risk-score
          collateral-ratio
        ))
      )
        (asserts! (get enabled token-info) err-unsupported-asset)
        (asserts! (<= dynamic-rate max-interest-rate) err-invalid-interest)
        (create-loan-internal 
          amount 
          asset-type-stx 
          none 
          collateral-amount 
          asset-type-sip10 
          (some collateral-token-contract) 
          none 
          u0 ;; Use dynamic rate
          duration
        )
      )
    )
  )
)

;; Create STX loan with NFT collateral
(define-public (create-stx-loan-with-nft-collateral 
  (amount uint) 
  (nft-contract principal) 
  (nft-id uint) 
  (max-interest-rate uint) 
  (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> nft-id u0) err-invalid-amount)
    (asserts! (and (>= max-interest-rate (var-get min-dynamic-rate)) (<= max-interest-rate (var-get max-dynamic-rate))) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    (asserts! (not (is-eq nft-contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq nft-contract (as-contract tx-sender))) err-invalid-token-contract)
    
    (let (
      (collection-info-result (map-get? supported-nft-collections { contract: nft-contract }))
    )
      (asserts! (is-some collection-info-result) err-unsupported-asset)
      (let (
        (collection-info (unwrap! collection-info-result err-unsupported-asset))
        (floor-price (get floor-price collection-info))
        (nft-risk-score (get risk-score collection-info))
        (collateral-ratio (if (> amount u0) (/ (* floor-price u10000) amount) u0))
        (combined-risk-score (if (> nft-risk-score u0) nft-risk-score risk-score-medium))
        (dynamic-rate (calculate-dynamic-interest-rate 
          (var-get base-interest-rate) 
          asset-type-stx 
          none 
          combined-risk-score
          collateral-ratio
        ))
      )
        (asserts! (get enabled collection-info) err-unsupported-asset)
        (asserts! (> floor-price u0) err-insufficient-collateral)
        (asserts! (>= collateral-ratio (var-get min-collateral-ratio)) err-insufficient-collateral)
        (asserts! (<= dynamic-rate max-interest-rate) err-invalid-interest)
        
        (create-loan-internal 
          amount 
          asset-type-stx 
          none 
          floor-price 
          asset-type-nft 
          (some nft-contract) 
          (some nft-id) 
          u0 ;; Use dynamic rate
          duration
        )
      )
    )
  )
)

;; Create SIP-10 token loan with STX collateral
(define-public (create-token-loan 
  (token-contract principal) 
  (amount uint) 
  (collateral-stx uint) 
  (max-interest-rate uint) 
  (duration uint))
  (begin
    ;; Validate input parameters
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> collateral-stx u0) err-invalid-amount)
    (asserts! (and (>= max-interest-rate (var-get min-dynamic-rate)) (<= max-interest-rate (var-get max-dynamic-rate))) err-invalid-interest)
    (asserts! (and (> duration u0) (<= duration (var-get max-loan-duration))) err-invalid-duration)
    (asserts! (not (is-eq token-contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq token-contract (as-contract tx-sender))) err-invalid-token-contract)
    
    (let (
      (token-info (unwrap! (map-get? supported-sip10-tokens { contract: token-contract }) err-unsupported-asset))
      (collateral-ratio (/ (* collateral-stx u10000) amount))
      (risk-score (calculate-risk-score tx-sender asset-type-stx none))
      (dynamic-rate (calculate-dynamic-interest-rate 
        (var-get base-interest-rate) 
        asset-type-sip10 
        (some token-contract) 
        risk-score
        collateral-ratio
      ))
    )
      (asserts! (get enabled token-info) err-unsupported-asset)
      (asserts! (<= dynamic-rate max-interest-rate) err-invalid-interest)
      
      (try! (stx-transfer? collateral-stx tx-sender (as-contract tx-sender)))
      (create-loan-internal 
        amount 
        asset-type-sip10 
        (some token-contract) 
        collateral-stx 
        asset-type-stx 
        none 
        none 
        u0 ;; Use dynamic rate
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
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender borrower))
    
    ;; Update supply tracking
    (update-asset-utilization asset-type-stx none amount u0 u0 true)
    
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

;; Fund token loan
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
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    
    ;; Update supply tracking
    (let (
      (asset-contract (get loan-asset-contract loan))
    )
      (update-asset-utilization asset-type-sip10 asset-contract amount u0 u0 true)
    )
    
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

;; Repay loan
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
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (and (>= interest-rate (var-get min-dynamic-rate)) (<= interest-rate (var-get max-dynamic-rate))) err-invalid-interest)
    (asserts! (> total-repayment u0) err-invalid-amount)
    (asserts! (> lender-payment u0) err-invalid-amount)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    
    ;; Handle STX loan repayment
    (if (is-eq (get loan-asset-type loan) asset-type-stx)
      (begin
        (try! (stx-transfer? lender-payment tx-sender lender))
        (if (> platform-fee-amount u0)
          (try! (stx-transfer? platform-fee-amount tx-sender contract-owner))
          true
        )
      )
      true ;; Token loan repayment would require trait implementation
    )
    
    ;; Return collateral based on type
    (if (is-eq (get collateral-asset-type loan) asset-type-stx)
      (let (
        (collateral-amt (get collateral-amount loan))
      )
        (try! (as-contract (stx-transfer? collateral-amt tx-sender borrower)))
      )
      true ;; Other collateral types would require trait implementation
    )
    
    ;; Update utilization tracking
    (let (
      (loan-asset-contract (get loan-asset-contract loan))
    )
      (update-asset-utilization (get loan-asset-type loan) loan-asset-contract u0 amount u1 false)
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
    (borrower (get borrower loan))
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
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> (get collateral-amount loan) u0) err-invalid-amount)
    (asserts! (>= current-block due-block) err-loan-overdue)
    
    ;; Transfer collateral to lender based on type
    (if (is-eq (get collateral-asset-type loan) asset-type-stx)
      (let (
        (collateral-amt (get collateral-amount loan))
      )
        (try! (as-contract (stx-transfer? collateral-amt tx-sender lender)))
      )
      true ;; Other collateral types would require trait implementation
    )
    
    ;; Update user stats for default
    (let (
      (borrower-stats (get-user-stats borrower))
      (current-defaults (get default-count borrower-stats))
    )
      (map-set user-stats
        { user: borrower }
        (merge borrower-stats { default-count: (+ current-defaults u1) })
      )
    )
    
    ;; Update utilization tracking
    (let (
      (loan-asset-contract (get loan-asset-contract loan))
    )
      (update-asset-utilization (get loan-asset-type loan) loan-asset-contract u0 (get amount loan) u1 false)
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
    (asserts! (> loan-id u0) (err err-invalid-amount))
    (asserts! (<= loan-id (var-get loan-counter)) (err err-not-found))
    (ok (map-get? loans loan-key))
  )
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
  (default-to
    { loans-created: u0, loans-funded: u0, total-borrowed-stx: u0, total-lent-stx: u0, reputation-score: u0, default-count: u0 }
    (map-get? user-stats { user: user })
  )
)

;; Calculate interest for a loan
(define-read-only (calculate-interest (principal-amount uint) (rate uint) (blocks-elapsed uint) (total-duration uint))
  (begin
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

;; Get current dynamic interest rate for a loan type
(define-read-only (get-dynamic-rate (asset-type uint) (asset-contract (optional principal)) (user principal) (collateral-type uint) (collateral-amount uint) (loan-amount uint))
  (begin
    (asserts! (> loan-amount u0) u0)
    (asserts! (> collateral-amount u0) u0)
    
    (let (
      (collateral-ratio (/ (* collateral-amount u10000) loan-amount))
      (risk-score (calculate-risk-score user collateral-type asset-contract))
    )
      (calculate-dynamic-interest-rate 
        (var-get base-interest-rate) 
        asset-type 
        asset-contract 
        risk-score
        collateral-ratio
      )
    )
  )
)

;; Get asset utilization data
(define-read-only (get-asset-utilization (asset-type uint) (asset-contract (optional principal)))
  (let (
    (utilization-key { asset-type: asset-type, contract: asset-contract })
    (utilization-data (map-get? asset-utilization utilization-key))
  )
    (match utilization-data
      data (some {
        total-supplied: (get total-supplied data),
        total-borrowed: (get total-borrowed data),
        active-loans: (get active-loans data),
        utilization-rate: (calculate-utilization-rate asset-type asset-contract)
      })
      none
    )
  )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    total-loans: (var-get loan-counter),
    platform-fee: (var-get platform-fee),
    max-duration: (var-get max-loan-duration),
    min-collateral-ratio: (var-get min-collateral-ratio),
    base-interest-rate: (var-get base-interest-rate),
    utilization-multiplier: (var-get utilization-multiplier),
    risk-multiplier: (var-get risk-multiplier),
    max-dynamic-rate: (var-get max-dynamic-rate),
    min-dynamic-rate: (var-get min-dynamic-rate)
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
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq contract (as-contract tx-sender))) err-invalid-token-contract)
    (asserts! (> decimals u0) err-invalid-amount)
    (asserts! (<= decimals u18) err-invalid-amount)
    
    (map-set supported-sip10-tokens
      { contract: contract }
      { enabled: true, decimals: decimals, supply: u0, demand: u0 }
    )
    (ok true)
  )
)

;; Remove supported SIP-10 token
(define-public (remove-supported-sip10-token (contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq contract (as-contract tx-sender))) err-invalid-token-contract)
    
    (map-set supported-sip10-tokens
      { contract: contract }
      { enabled: false, decimals: u0, supply: u0, demand: u0 }
    )
    (ok true)
  )
)

;; Add supported NFT collection
(define-public (add-supported-nft-collection (contract principal) (floor-price uint) (risk-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq contract (as-contract tx-sender))) err-invalid-token-contract)
    (asserts! (> floor-price u0) err-invalid-amount)
    (asserts! (and (>= risk-score risk-score-safe) (<= risk-score risk-score-very-high)) err-invalid-risk-score)
    
    (map-set supported-nft-collections
      { contract: contract }
      { enabled: true, floor-price: floor-price, risk-score: risk-score }
    )
    (ok true)
  )
)

;; Update NFT collection floor price and risk score
(define-public (update-nft-collection (contract principal) (new-floor-price uint) (new-risk-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq contract (as-contract tx-sender))) err-invalid-token-contract)
    (asserts! (> new-floor-price u0) err-invalid-amount)
    (asserts! (and (>= new-risk-score risk-score-safe) (<= new-risk-score risk-score-very-high)) err-invalid-risk-score)
    (asserts! (is-some (map-get? supported-nft-collections { contract: contract })) err-not-found)
    
    (map-set supported-nft-collections
      { contract: contract }
      { enabled: true, floor-price: new-floor-price, risk-score: new-risk-score }
    )
    (ok true)
  )
)

;; Remove supported NFT collection
(define-public (remove-supported-nft-collection (contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq contract tx-sender)) err-invalid-token-contract)
    (asserts! (not (is-eq contract (as-contract tx-sender))) err-invalid-token-contract)
    
    (map-set supported-nft-collections
      { contract: contract }
      { enabled: false, floor-price: u0, risk-score: u0 }
    )
    (ok true)
  )
)

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

;; Update dynamic rate parameters
(define-public (set-dynamic-rate-params (base-rate uint) (util-multiplier uint) (risk-mult uint) (max-rate uint) (min-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= base-rate u50) (<= base-rate u1000)) err-invalid-interest) ;; 0.5% - 10%
    (asserts! (<= util-multiplier u500) err-invalid-amount) ;; Max 5% utilization impact
    (asserts! (<= risk-mult u300) err-invalid-amount) ;; Max 3% risk impact
    (asserts! (and (>= max-rate u500) (<= max-rate u5000)) err-invalid-interest) ;; 5% - 50% max
    (asserts! (and (>= min-rate u50) (<= min-rate u200)) err-invalid-interest) ;; 0.5% - 2% min
    (asserts! (> max-rate min-rate) err-invalid-interest)
    
    (var-set base-interest-rate base-rate)
    (var-set utilization-multiplier util-multiplier)
    (var-set risk-multiplier risk-mult)
    (var-set max-dynamic-rate max-rate)
    (var-set min-dynamic-rate min-rate)
    (ok true)
  )
)