# BitBazaar - Decentralized Bitcoin Marketplace Protocol

**BitBazaar** is a decentralized, trustless marketplace protocol built on the **Stacks L2** blockchain, designed to enable the secure trading of digital and physical goods with **Bitcoin-settled transactions**. The protocol supports direct sales, auctions, brand verification, and a transparent review system — all governed by smart contracts and powered by Bitcoin’s security and Stacks’ programmability.

## Overview

BitBazaar provides the infrastructure for building decentralized e-commerce platforms that:

* **Enable Direct Sales**: Sellers can list goods and accept instant Bitcoin-backed payments.
* **Facilitate Auctions**: Competitive bidding with escrow-secured settlement.
* **Support Brand Verification**: Brands can be verified by the protocol owner to reduce fraud.
* **Incorporate Reviews**: Buyers can rate and leave feedback for products transparently.
* **Trustlessly Handle Payments**: Including fee calculation and automated disbursement via `stx-transfer?`.

## Core Features

### Brand Registration and Verification

* Anyone can register a brand.
* Only the **contract owner** can verify brands.
* Verified brands improve credibility in the marketplace.

### Direct Listings

* Sellers can list products for fixed-price sales.
* Products must have non-empty names, descriptions, and valid prices.
* Buyers can purchase with STX; platform fees are deducted automatically.

### Auctions

* Sellers can create time-limited auctions with a minimum bid.
* Bidders compete by locking STX, which is returned to outbid participants.
* On completion, the winning bid (minus fees) is transferred to the seller.

### Reviews

* Buyers can review purchased products with ratings (0–5 stars) and comments.
* Reviews are tied to the product ID and reviewer principal.

## Security and Trustlessness

* **Escrow-like Bidding**: Funds are locked during auctions and safely returned if outbid.
* **Immutable Data Storage**: All data (products, auctions, reviews) is recorded on-chain.
* **Permissioned Admin Functions**: Only the contract owner can verify brands or change certain system parameters.
* **Prevention of Invalid States**: Built-in validations ensure name/description lengths, price sanity, and sufficient funds.

## Platform Fee

* A configurable platform fee is applied on every sale and auction (default: **2.5%**).
* Fees are routed to the contract owner address for sustainability.

## Function Overview

### Public Functions

| Function                                                 | Description                               |
| -------------------------------------------------------- | ----------------------------------------- |
| `register-brand(name)`                                   | Registers a new brand.                    |
| `verify-brand(brand)`                                    | Verifies a brand (contract-owner only).   |
| `list-product(name, description, price)`                 | Lists a fixed-price product.              |
| `purchase-product(product-id)`                           | Allows purchase of available products.    |
| `create-auction(name, description, min-price, duration)` | Creates a new auction listing.            |
| `place-bid(product-id, bid-amount)`                      | Places a bid on an active auction.        |
| `end-auction(product-id)`                                | Finalizes an auction and transfers funds. |
| `add-review(product-id, rating, comment)`                | Submits a product review.                 |

### Read-Only Functions

| Function                           | Description                  |
| ---------------------------------- | ---------------------------- |
| `get-product(product-id)`          | Retrieves product details.   |
| `get-brand(brand)`                 | Retrieves brand metadata.    |
| `get-review(product-id, reviewer)` | Fetches a specific review.   |
| `get-auction(product-id)`          | Returns auction information. |

## Error Codes

| Code   | Meaning                           |
| ------ | --------------------------------- |
| `u100` | Unauthorized (owner-only access). |
| `u101` | Not brand owner.                  |
| `u102` | Invalid product price.            |
| `u103` | Product not found.                |
| `u104` | Insufficient funds.               |
| `u105` | Auction ended.                    |
| `u106` | Bid too low.                      |
| `u107` | No active auction.                |
| `u108` | Invalid auction duration.         |
| `u109` | Invalid rating value.             |
| `u110` | STX transfer failed.              |
| `u111` | Empty product name.               |
| `u112` | Empty product description.        |

## Data Structures

### Maps

* `Brands`: brand metadata including name, verified status, and creation time.
* `Products`: listing metadata with auction flag.
* `Auctions`: manages auction lifecycle, bids, and block-based timing.
* `Reviews`: product-specific user feedback.

### Variables

* `platform-fee`: marketplace fee in basis points (e.g., 25 = 2.5%).
* `product-counter`: incremental ID for new product listings.

## Deployment & Usage Notes

* Built for [Clarity](https://docs.stacks.co/write-smart-contracts/clarity-overview), the smart contract language on Stacks.
* Requires `stx-transfer?` and `unwrap!` to be used for transactional safety.
* Recommended to deploy with administrative controls secured via multi-sig for production-grade marketplaces.

## Future Improvements (Suggested)

* Dispute resolution system or decentralized arbitration.
* NFT support for digital goods.
* Buyer protection and escrow release logic.
* Integration with Stacks SIPs for decentralized identities (DIDs).
* Admin-settable `platform-fee`.

## Contributing

BitBazaar is open to collaboration. Whether you're building on Stacks or extending Bitcoin commerce — feel free to fork, audit, or suggest improvements via issues or pull requests.
