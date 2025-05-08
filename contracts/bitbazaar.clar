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