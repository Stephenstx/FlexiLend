# FlexiLend 🚀

A flexible multi-asset peer-to-peer lending platform built on Stacks blockchain, enabling users to create custom loan terms with support for STX, SIP-10 tokens, and NFTs as collateral.

## 🎯 Overview

FlexiLend revolutionizes decentralized lending by allowing borrowers to set their own terms while ensuring lenders are protected through multi-asset collateral requirements. The platform uses smart contracts to automate loan creation, funding, repayment, and liquidation processes across multiple asset types.

## ✨ Key Features

- **Multi-Asset Support**: Borrow and lend STX, SIP-10 tokens with various collateral types
- **NFT Collateral**: Use supported NFT collections as loan collateral
- **SIP-10 Token Support**: Lend and borrow various fungible tokens
- **Custom Loan Terms**: Borrowers can set their own interest rates and loan durations
- **Flexible Collateral**: Accept STX, SIP-10 tokens, or NFTs as collateral
- **Automated Liquidation**: Overdue loans are automatically liquidated to protect lenders
- **Reputation System**: Track user lending history and build trust across all asset types
- **Platform Fees**: Sustainable 2.5% fee structure for platform maintenance
- **Admin Controls**: Manage supported assets and collection parameters

## 🎨 Supported Asset Types

### Lending Assets
- **STX**: Native Stacks tokens
- **SIP-10 Tokens**: Community and protocol tokens following the SIP-010 standard

### Collateral Assets
- **STX**: Native Stacks tokens
- **SIP-10 Tokens**: Supported fungible tokens as collateral
- **NFTs**: Approved NFT collections with floor price valuations

## 🛠️ Technical Implementation

### Smart Contract Architecture

The FlexiLend smart contract is built using Clarity and includes:

- **Multi-Asset Loan Management**: Create, fund, repay, and liquidate loans across different asset types
- **Collateral Handling**: Automatic collateral lock and release for STX, SIP-10, and NFT assets
- **Asset Registry**: Manage supported SIP-10 tokens and NFT collections
- **Interest Calculation**: Proportional interest based on loan duration
- **User Statistics**: Track lending history and reputation scores across all assets
- **Admin Controls**: Platform fee and supported asset management

### Key Functions

#### STX Loans
- `create-stx-loan`: Create STX loan with STX collateral
- `create-stx-loan-sip10-collateral`: Create STX loan with SIP-10 token collateral
- `create-stx-loan-nft-collateral`: Create STX loan with NFT collateral
- `fund-stx-loan`: Fund an STX loan request
- `repay-stx-loan`: Repay an STX loan with interest

#### SIP-10 Token Loans
- `create-sip10-loan`: Create SIP-10 token loan with STX collateral
- `fund-sip10-loan`: Fund a SIP-10 token loan request
- `repay-sip10-loan`: Repay a SIP-10 token loan with interest

#### General Functions
- `liquidate-loan`: Liquidate overdue loans (any asset type)
- `get-loan`: Retrieve loan details
- `get-user-stats`: View user lending statistics

#### Admin Functions
- `add-supported-sip10-token`: Add new supported SIP-10 token
- `add-supported-nft-collection`: Add new supported NFT collection
- `update-nft-floor-price`: Update NFT collection floor prices

## 📊 Platform Parameters

- **Minimum Collateral Ratio**: 150%
- **Platform Fee**: 2.5%
- **Maximum Loan Duration**: ~1 year (52,560 blocks)
- **Interest Rate Range**: 1% - 100% annually
- **Supported Assets**: Admin-managed whitelist

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet with STX tokens
- SIP-10 tokens (for token loans/collateral)
- NFTs from supported collections (for NFT collateral)
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Run `clarinet check` to verify contract syntax
3. Deploy to testnet using `clarinet integrate`

### Usage Examples

#### STX Loan with STX Collateral
```clarity
;; Create a loan requesting 1000 STX with 1500 STX collateral
;; 5% annual interest rate for 5256 blocks (~1 month)
(contract-call? .flexilend create-stx-loan u1000000000 u1500000000 u500 u5256)

;; Fund the loan (as a lender)
(contract-call? .flexilend fund-stx-loan u1)

;; Repay the loan (as borrower)
(contract-call? .flexilend repay-stx-loan u1)
```

#### STX Loan with SIP-10 Token Collateral
```clarity
;; Create STX loan with SIP-10 token collateral
(contract-call? .flexilend create-stx-loan-sip10-collateral 
  u1000000000  ;; 1000 STX loan amount
  u2000000000  ;; 2000 token units as collateral
  .my-token    ;; SIP-10 token contract
  u500         ;; 5% interest
  u5256        ;; 1 month duration
)
```

#### STX Loan with NFT Collateral
```clarity
;; Create STX loan with NFT collateral
(contract-call? .flexilend create-stx-loan-nft-collateral
  u500000000   ;; 500 STX loan amount
  .my-nft      ;; NFT contract
  u123         ;; NFT ID
  u750         ;; 7.5% interest
  u2628        ;; 2 weeks duration
)
```

#### SIP-10 Token Loan
```clarity
;; Create SIP-10 token loan with STX collateral
(contract-call? .flexilend create-sip10-loan
  .my-token      ;; Token to borrow
  u1000000000    ;; Token amount to borrow
  u1500000000    ;; STX collateral amount
  u500           ;; 5% interest
  u5256          ;; 1 month duration
)

;; Fund the token loan
(contract-call? .flexilend fund-sip10-loan u1 .my-token)

;; Repay the token loan
(contract-call? .flexilend repay-sip10-loan u1 .my-token)
```

## 🔧 Development Setup

```bash
# Check contract syntax
clarinet check

# Run tests
clarinet test

# Start local development environment
clarinet integrate
```

## 📈 Platform Statistics

The contract tracks comprehensive metrics including:
- Total loans created across all asset types
- User lending history by asset type
- Reputation scores based on multi-asset activity
- Platform fee collection
- Liquidation events across different collateral types
- Supported asset registry

## 🔐 Security Features

- **Input Validation**: All parameters are validated before execution
- **Access Control**: Function-specific authorization checks
- **Multi-Asset Collateral Protection**: Automatic collateral management for all supported asset types
- **Asset Whitelisting**: Only pre-approved SIP-10 tokens and NFT collections are supported
- **Floor Price Management**: NFT valuations based on admin-managed floor prices
- **Overflow Protection**: Safe arithmetic operations
- **Error Handling**: Comprehensive error codes and messages

## 🎯 Asset Management

### SIP-10 Token Support
- Admin can add/remove supported SIP-10 tokens
- Decimal precision tracking for accurate calculations
- Enable/disable tokens without removing from registry

### NFT Collection Support
- Admin can add/remove supported NFT collections
- Floor price tracking for collateral valuation
- Regular price updates to reflect market conditions

## Roadmap

- [x] **Multi-Edition NFTs**: Support for limited edition artworks with sequential minting and rarity tracking
- [ ] **Auction System**: Time-based bidding mechanism with automatic settlement and reserve prices
- [ ] **Collaborative Artworks**: Multi-artist collaboration support with split ownership and revenue sharing
- [ ] **Art Investment Pools**: Fractional ownership system allowing multiple investors to co-own high-value artworks
- [ ] **Dynamic Pricing Algorithm**: AI-driven pricing suggestions based on artist reputation, market trends, and artwork characteristics
- [ ] **Cross-Chain Bridge**: Integration with other blockchain networks for broader artwork accessibility
- [ ] **Virtual Gallery System**: 3D virtual spaces for artwork display and immersive viewing experiences
- [ ] **Artwork Lending Protocol**: Temporary artwork transfers for exhibitions, galleries, and events
- [ ] **Artist Mentorship Program**: Structured system connecting established artists with emerging creators
- [ ] **Carbon Offset Integration**: Environmental impact tracking and automatic carbon credit purchasing for eco-conscious art trading

## 🤝 Contributing

We welcome contributions to improve FlexiLend! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 🔄 Migration Guide

For users of the previous STX-only version:
- Existing STX loan functionality remains unchanged
- New multi-asset features are additive
- All existing loans continue to function normally
- Upgrade to access new SIP-10 and NFT collateral options

