;; fund-raiser.clar
;; A simple FundRaiser smart contract on Stacks blockchain using Clarity 4
;; This contract allows users to donate STX towards a funding goal, and the owner can withdraw once the goal is reached.

;; Define constants for immutable values
(define-constant CONTRACT-OWNER tx-sender)  ;; The deployer of the contract is the owner
(define-constant FUNDING-GOAL u1000000)     ;; Funding goal: 1 STX (1000000 microSTX)

;; Define data variables for mutable state
(define-data-var total-funded uint u0)      ;; Total amount funded so far, starts at 0

;; Define a map to track donor contributions
;; Key: donor principal, Value: total amount donated by that donor
(define-map donors principal uint)

;; Public function: fund
;; Allows any user to donate STX to the fundraiser
;; Parameters: amount (uint) - the amount of microSTX to donate
;; Returns: (response bool uint) - (ok true) on success, error code on failure
(define-public (fund (amount uint))
  (begin
    ;; Security check: ensure amount is greater than 0
    (asserts! (> amount u0) (err u1))  ;; Error u1: Invalid amount

    ;; Transfer STX from donor to contract using try! for error handling
    ;; stx-transfer? returns (response bool uint), try! unwraps it or returns error
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update total-funded (Clarity handles overflow by panicking, but we assume amounts are reasonable)
    (var-set total-funded (+ (var-get total-funded) amount))

    ;; Update donor's contribution in the map
    ;; If donor doesn't exist, default to 0, then add the new amount
    (map-set donors tx-sender (+ (default-to u0 (map-get? donors tx-sender)) amount))

     (asserts! (< (var-get total-funded) FUNDING-GOAL) (err u5))  ;; Error u5: Goal already reached

    ;; Return success
    (ok true)
  )
)

;; Public function: withdraw
;; Allows the owner to withdraw all funds if the goal is reached
;; No parameters
;; Returns: (response bool uint) - (ok true) on success, error code on failure
(define-public (withdraw)
  (let ((balance (var-get total-funded)))  ;; Cache the balance to avoid multiple reads
    ;; Security check: only owner can call
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err u2))  ;; Error u2: Unauthorized

    ;; Security check: ensure goal is reached
    (asserts! (>= balance FUNDING-GOAL) (err u3))  ;; Error u3: Goal not reached

    ;; Transfer all funds to owner using try! for error handling
    ;; Use as-contract to transfer from contract's balance
    (try! (as-contract (stx-transfer? balance tx-sender CONTRACT-OWNER)))

    ;; Reset total-funded to 0 after successful withdrawal
    (var-set total-funded u0)

    ;; Return success
    (ok true)
  )
)

;; Read-only function: get-balance
;; Returns the current total funded amount
;; Returns: uint - total-funded
(define-read-only (get-balance)
  (var-get total-funded)
)

;; Read-only function: get-goal
;; Returns the funding goal
;; Returns: uint - FUNDING-GOAL
(define-read-only (get-goal)
  FUNDING-GOAL
)

;; Read-only function: get-donor-amount
;; Returns the total amount donated by a specific donor
;; Parameters: donor (principal) - the donor's principal
;; Returns: uint - donation amount or 0 if not found
(define-read-only (get-donor-amount (donor principal))
  (default-to u0 (map-get? donors donor))
)

;; Read-only function: get-owner
;; Returns the contract owner
;; Returns: principal - CONTRACT-OWNER
(define-read-only (get-owner)
  CONTRACT-OWNER
)
