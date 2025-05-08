;; Title: BitBazaar - Decentralized Bitcoin Marketplace Protocol
;; 
;; Summary: A secure, trustless marketplace for digital and physical goods on Stacks L2,
;; enabling direct sales and auctions with Bitcoin-powered settlement.
;;
;; Description: BitBazaar provides a comprehensive marketplace infrastructure with brand 
;; verification, direct sales, auctions, and a feedback system - all secured by Bitcoin's
;; reliability and Stacks' programmability. The protocol handles product listings, 
;; secure transactions, escrow for auctions, and transparent reviews to create
;; a self-sustaining ecosystem for commerce in the Bitcoin economy.

;; Constants and Error Codes

(define-constant contract-owner tx-sender)

;; Error codes - Administrative
(define-constant err-owner-only (err u100))
(define-constant err-not-brand-owner (err u101))
(define-constant err-transfer-failed (err u110))

;; Error codes - Listings
(define-constant err-invalid-price (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-empty-name (err u111))
(define-constant err-empty-description (err u112))

;; Error codes - Payments
(define-constant err-insufficient-funds (err u104))

;; Error codes - Auctions
(define-constant err-auction-ended (err u105))
(define-constant err-bid-too-low (err u106))
(define-constant err-no-active-auction (err u107))
(define-constant err-invalid-duration (err u108))

;; Error codes - Reviews
(define-constant err-invalid-rating (err u109))

;; Validation constants
(define-constant min-name-length u1)
(define-constant min-description-length u1)

;; Data Variables

(define-data-var platform-fee uint u25) ;; 2.5% fee represented as 25/1000
(define-data-var product-counter uint u0)

;; Data Maps

(define-map Brands principal 
  {
    name: (string-ascii 50),
    verified: bool,
    created-at: uint
  }
)

(define-map Products uint 
  {
    brand: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    price: uint,
    available: bool,
    created-at: uint,
    is-auction: bool
  }
)

(define-map Auctions uint
  {
    end-block: uint,
    min-price: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    is-active: bool
  }
)

(define-map Reviews {product-id: uint, reviewer: principal}
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint
  }
)

;; Brand Management Functions

;; Register a new brand on the marketplace
(define-public (register-brand (name (string-ascii 50)))
  (let
    ((brand-data {
      name: name,
      verified: false,
      created-at: stacks-block-height
    }))
    (ok (map-set Brands tx-sender brand-data))
  )
)

;; Verify a brand (restricted to contract owner)
(define-public (verify-brand (brand principal))
  (if (is-eq tx-sender contract-owner)
    (let
      ((brand-data (unwrap! (map-get? Brands brand) (err err-not-brand-owner))))
      ;; Check that the brand exists before modifying
      (if (is-some (map-get? Brands brand))
        (ok (map-set Brands brand (merge brand-data {verified: true})))
        (err err-not-brand-owner)))
    (err err-owner-only))
)

;; Direct Sale Functions

;; List a new product for direct sale
(define-public (list-product 
    (name (string-ascii 100))
    (description (string-ascii 500))
    (price uint)
  )
  (let
    ((brand (unwrap! (map-get? Brands tx-sender) (err err-not-brand-owner)))
     (product-id (+ (var-get product-counter) u1))
     (name-length (len name))
     (description-length (len description)))
    
    ;; Add validation for non-empty name and description
    (if (>= name-length min-name-length)
      (if (>= description-length min-description-length)
        (if (> price u0)
          (begin
            (var-set product-counter product-id)
            (ok (map-set Products product-id {
              brand: tx-sender,
              name: name,
              description: description,
              price: price,
              available: true,
              created-at: stacks-block-height,
              is-auction: false
            })))
          (err err-invalid-price))
        (err err-empty-description))
      (err err-empty-name))
  )
)

;; Purchase a listed product
(define-public (purchase-product (product-id uint))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (price (get price product))
     (brand (get brand product))
     (fee (/ (* price (var-get platform-fee)) u1000)))
    
    (if (and
          (get available product)
          (not (get is-auction product))
          (>= (stx-get-balance tx-sender) price))
      (let
        ((fee-transfer-result (stx-transfer? fee tx-sender contract-owner))
         (payment-transfer-result (stx-transfer? (- price fee) tx-sender brand)))
        
        (if (and 
              (is-ok fee-transfer-result)
              (is-ok payment-transfer-result))
          (ok (map-set Products product-id 
                (merge product {available: false})))
          (err err-transfer-failed)))
      (err err-insufficient-funds))
  )
)

;; Auction Functions

;; Create an auction for a product
(define-public (create-auction
    (name (string-ascii 100))
    (description (string-ascii 500))
    (min-price uint)
    (duration uint)
  )
  (let
    ((brand (unwrap! (map-get? Brands tx-sender) (err err-not-brand-owner)))
     (product-id (+ (var-get product-counter) u1))
     (end-block (+ stacks-block-height duration))
     (name-length (len name))
     (description-length (len description)))
    
    (if (>= name-length min-name-length)
      (if (>= description-length min-description-length)
        (if (and (>= duration u10) (> min-price u0))
          (begin
            (var-set product-counter product-id)
            (map-set Products product-id {
              brand: tx-sender,
              name: name,
              description: description,
              price: min-price,
              available: true,
              created-at: stacks-block-height,
              is-auction: true
            })
            (ok (map-set Auctions product-id {
              end-block: end-block,
              min-price: min-price,
              highest-bid: u0,
              highest-bidder: none,
              is-active: true
            })))
          (if (< duration u10)
            (err err-invalid-duration)
            (err err-invalid-price)))
        (err err-empty-description))
      (err err-empty-name))
  )
)

;; Place a bid on an active auction
(define-public (place-bid (product-id uint) (bid-amount uint))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (auction (unwrap! (map-get? Auctions product-id) (err err-no-active-auction))))
    
    (if (and 
          (get is-active auction)
          (<= stacks-block-height (get end-block auction))
          (>= bid-amount (get min-price auction))
          (> bid-amount (get highest-bid auction))
          (>= (stx-get-balance tx-sender) bid-amount))
      (let
        ((return-result (match (get highest-bidder auction)
          prev-bidder (stx-transfer? (get highest-bid auction) contract-owner prev-bidder)
          (ok true)))
         (bid-result (stx-transfer? bid-amount tx-sender contract-owner)))
        
        (if (and (is-ok return-result) (is-ok bid-result))
          (ok (map-set Auctions product-id
            (merge auction {
              highest-bid: bid-amount,
              highest-bidder: (some tx-sender)
            })))
          (err err-transfer-failed)))
      ;; Error handling with nested if statements
      (if (not (get is-active auction))
        (err err-auction-ended)
        (if (> stacks-block-height (get end-block auction))
          (err err-auction-ended)
          (if (< bid-amount (get min-price auction))
            (err err-bid-too-low)
            (if (<= bid-amount (get highest-bid auction))
              (err err-bid-too-low)
              (err err-insufficient-funds))))))
  )
)

;; Finalize an auction after its end time
(define-public (end-auction (product-id uint))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (auction (unwrap! (map-get? Auctions product-id) (err err-no-active-auction)))
     (brand (get brand product)))
    
    (if (and 
          (get is-active auction)
          (>= stacks-block-height (get end-block auction)))
      (match (get highest-bidder auction)
        winner 
          (let ((bid-amount (get highest-bid auction))
                (fee (/ (* bid-amount (var-get platform-fee)) u1000))
                (fee-transfer (stx-transfer? fee contract-owner contract-owner))
                (payment-transfer (stx-transfer? (- bid-amount fee) contract-owner brand)))
            (if (and (is-ok fee-transfer) (is-ok payment-transfer))
              (begin
                (map-set Products product-id (merge product {available: false}))
                (ok (map-set Auctions product-id (merge auction {is-active: false}))))
              (err err-transfer-failed)))
        (err err-no-active-auction))
      (if (not (get is-active auction))
        (err err-auction-ended)
        (err err-auction-ended)))
  )
)

;; Review System

;; Add a review for a product
(define-public (add-review 
    (product-id uint)
    (rating uint)
    (comment (string-ascii 200)))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (comment-length (len comment)))
    ;; Make sure product exists and comment is not empty
    (if (is-some (map-get? Products product-id))
      (if (>= comment-length min-description-length)
        (if (<= rating u5)
          (ok (map-set Reviews 
            {product-id: product-id, reviewer: tx-sender}
            {
              rating: rating,
              comment: comment,
              timestamp: stacks-block-height
            }))
          (err err-invalid-rating))
        (err err-empty-description))
      (err err-listing-not-found))
  )
)

;; Read-only Functions

;; Get product details
(define-read-only (get-product (product-id uint))
  (ok (map-get? Products product-id))
)

;; Get brand details
(define-read-only (get-brand (brand principal))
  (ok (map-get? Brands brand))
)

;; Get a specific review
(define-read-only (get-review (product-id uint) (reviewer principal))
  (ok (map-get? Reviews {product-id: product-id, reviewer: reviewer}))
)

;; Get auction details
(define-read-only (get-auction (product-id uint))
  (ok (map-get? Auctions product-id))
)