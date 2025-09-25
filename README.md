# FlexiLend 🚀

A flexible multi-asset peer-to-peer lending platform built on Stacks blockchain, enabling users to create custom loan terms with support for STX, SIP-10 tokens, and NFTs as collateral. **Now featuring dynamic interest rates based on real-time supply/demand and risk assessment!**

## 🎯 Overview

FlexiLend revolutionizes decentralized lending by allowing borrowers to set their own terms while ensuring lenders are protected through multi-asset collateral requirements. The platform uses smart contracts to automate loan creation, funding, repayment, and liquidation processes across multiple asset types. Our new **dynamic interest rate system** automatically adjusts rates based on market conditions and borrower risk profiles.

## ✨ Key Features

- **🔄 Dynamic Interest Rates**: Algorithm-based rates that adjust based on supply/demand and risk assessment
- **📊 Real-time Market Analysis**: Supply/demand tracking for optimal rate discovery
- **🎯 Risk-Based Pricing**: User reputation and collateral type influence interest rates
- **Multi-Asset Support**: Borrow and lend STX, SIP-10 tokens with various collateral types
- **NFT Collateral**: Use supported NFT collections as loan collateral with risk scoring
- **SIP-10 Token Support**: Lend and borrow various fungible tokens
- **Custom Loan Terms**: Borrowers can set maximum acceptable interest rates
- **Flexible Collateral**: Accept STX, SIP-10 tokens, or NFTs as collateral
- **Automated Liquidation**: Overdue loans are automatically liquidated to protect lenders
- **Advanced Reputation System**: Track user lending history, defaults, and build trust
- **Platform Fees**: Sustainable 2.5% fee structure for platform maintenance
- **Admin Controls**: Manage supported assets and collection parameters

## 🔄 Dynamic Interest Rate System

### How It Works

The platform automatically calculates optimal interest rates using multiple factors:

1. **Base Rate**: Platform-wide baseline interest rate (default: 5%)
2. **Utilization Rate**: Higher demand → Higher rates
3. **Risk Assessment**: User history and collateral type influence
4. **Collateral Ratio**: Higher collateral → Lower rates

### Rate Calculation Formula

```
Dynamic Rate = Base Rate + (Utilization Impact) + (Risk Impact) + (Collateral Impact)
```

### Risk Scoring System

- **Safe (1)**: High reputation, no defaults → Lowest rates
- **Low (2)**: Good reputation, no recent defaults
- **Medium (3)**: New users or average reputation  
- **High (4)**: Users with 1 default or low reputation
- **Very High (5)**: Multiple defaults → Highest rates

### Collateral Risk Assessment

- **STX Collateral**: Baseline risk
- **SIP-10 Tokens**: Risk varies by token stability
- **NFTs**: Collection-specific risk scores set by admins

### Rate Bounds

- **Minimum Rate**: 1% (adjustable by admin)
- **Maximum Rate**: 20% (adjustable by admin)
- **Collateral Bonus**: 200%+ collateral gets 0.5% rate discount

## 🎨 Supported Asset Types

### Lending Assets
- **STX**: Native Stacks tokens
- **SIP-10 Tokens**: Community and protocol tokens following the SIP-010 standard

### Collateral Assets
- **STX**: Native Stacks tokens
- **SIP-10 Tokens**: Supported fungible tokens as collateral
- **NFTs**: Approved NFT collections with floor price valuations and risk scores

## 🛠️ Technical Implementation

### Smart Contract Architecture

The FlexiLend smart contract is built using Clarity and includes:

- **Dynamic Rate Engine**: Real-time interest rate calculation based on market conditions
- **Supply/Demand Tracking**: Monitor asset utilization for rate optimization
- **Risk Assessment Module**: User reputation and collateral risk analysis
- **Multi-Asset Loan Management**: Create, fund, repay, and liquidate loans across different asset types
- **Collateral Handling**: Automatic collateral lock and release for STX, SIP-10, and NFT assets
- **Asset Registry**: Manage supported SIP-10 tokens and NFT collections with risk scores
- **Advanced User Statistics**: Track lending history, defaults, and reputation scores
- **Admin Controls**: Platform fee and supported asset management

### Key Functions

#### STX Loans with Dynamic Rates
- `create-stx-loan(amount, collateral, max-rate, duration)`: Create STX loan with maximum acceptable rate
- `create-stx-loan-with-token-collateral`: STX loan with SIP-10 token collateral
- `create-stx-loan-with-nft-collateral`: STX loan with NFT collateral
- `fund-stx-loan`: Fund an STX loan request
- `repay-loan`: Repay any loan with calculated interest

#### SIP-10 Token Loans
- `create-token-loan`: Create SIP-10 token loan with STX collateral
- `fund-token-loan`: Fund a SIP-10 token loan request

#### Dynamic Rate Functions
- `get-dynamic-rate`: Calculate current dynamic rate for specific parameters
- `get-asset-utilization`: View real-time supply/demand data

#### General Functions
- `liquidate-loan`: Liquidate overdue loans (any asset type)
- `get-loan`: Retrieve loan details including applied dynamic rate
- `get-user-stats`: View user lending statistics including default history

#### Admin Functions
- `add-supported-sip10-token`: Add new supported SIP-10 token
- `add-supported-nft-collection`: Add NFT collection with risk score
- `update-nft-collection`: Update NFT floor prices and risk scores
- `set-dynamic-rate-params`: Configure dynamic rate algorithm parameters

## 📊 Platform Parameters

- **Base Interest Rate**: 5% (adjustable)
- **Minimum Collateral Ratio**: 150%
- **Platform Fee**: 2.5%
- **Maximum Loan Duration**: ~1 year (52,560 blocks)
- **Dynamic Rate Range**: 1% - 20% annually (adjustable)
- **Utilization Impact**: Up to 2% rate adjustment based on supply/demand
- **Risk Impact**: Up to 1% rate adjustment based on user risk score
- **Supported Assets**: Admin-managed whitelist with risk assessments

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

#### STX Loan with Dynamic Rates
```clarity
;; Create a loan requesting 1000 STX with 1500 STX collateral
;; Maximum acceptable rate: 8%, duration: 1 month
;; Actual rate will be calculated dynamically based on market conditions
(contract-call? .flexilend create-stx-loan u1000000000 u1500000000 u800 u5256)

;; Check what the current dynamic rate would be
(contract-call? .flexilend get-dynamic-rate 
  u1 ;; STX asset type
  none ;; No specific contract for STX
  tx-sender ;; Your address
  u1 ;; STX collateral type
  u1500000000 ;; Collateral amount
  u1000000000 ;; Loan amount
)

;; Fund the loan (as a lender)
(contract-call? .flexilend fund-stx-loan u1)

;; Repay the loan (as borrower) - interest calculated based on dynamic rate
(contract-call? .flexilend repay-loan u1)
```

#### STX Loan with SIP-10 Token Collateral
```clarity
;; Create STX loan with SIP-10 token collateral
;; Rate adjusted based on token risk and user history
(contract-call? .flexilend create-stx-loan-with-token-collateral 
  u1000000000  ;; 1000 STX loan amount
  u2000000000  ;; 2000 token units as collateral
  .my-token    ;; SIP-10 token contract
  u900         ;; Max 9% interest rate
  u5256        ;; 1 month duration
)
```

#### STX Loan with NFT Collateral
```clarity
;; Create STX loan with NFT collateral
;; Rate influenced by NFT collection risk score
(contract-call? .flexilend create-stx-loan-with-nft-collateral
  u500000000   ;; 500 STX loan amount
  .my-nft      ;; NFT contract
  u123         ;; NFT ID
  u1000        ;; Max 10% interest rate
  u2628        ;; 2 weeks duration
)
```

#### Check Market Data
```clarity
;; Check current utilization for STX loans
(contract-call? .flexilend get-asset-utilization u1 none)

;; Check platform statistics including dynamic rate parameters
(contract-call? .flexilend get-platform-stats)
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
- Real-time supply and demand for each asset type
- Utilization rates and dynamic interest rate adjustments
- User risk scores and default history
- Total loans created across all asset types
- Platform fee collection and liquidation events
- Supported asset registry with risk assessments

## 🔐 Security Features

- **Advanced Input Validation**: All parameters validated with comprehensive checks
- **Dynamic Risk Assessment**: Real-time risk evaluation for rate adjustment
- **Access Control**: Function-specific authorization checks
- **Multi-Asset Collateral Protection**: Automatic collateral management with risk scoring
- **Asset Whitelisting**: Only pre-approved assets with risk assessments
- **Market Manipulation Protection**: Rate bounds prevent extreme adjustments
- **Default Tracking**: User default history influences future rates
- **Overflow Protection**: Safe arithmetic operations throughout
- **Error Handling**: Comprehensive error codes and messages

## 🎯 Asset Management

### SIP-10 Token Support
- Admin can add/remove supported SIP-10 tokens
- Supply and demand tracking for each token
- Decimal precision tracking for accurate calculations
- Individual utilization rates per token

### NFT Collection Support
- Admin can add/remove supported NFT collections with risk scores
- Floor price tracking for collateral valuation
- Risk-based interest rate adjustments
- Regular price and risk updates to reflect market conditions

### Dynamic Rate Administration
- Adjust base interest rates based on market conditions
- Configure utilization and risk multipliers
- Set minimum and maximum rate bounds
- Monitor and optimize algorithm parameters

## 📊 Market Dynamics

### Supply and Demand Tracking
- **Real-time Monitoring**: Track supply and demand for each asset
- **Utilization Rates**: Calculate current market utilization
- **Rate Adjustments**: Automatic rate changes based on market conditions
- **Market Data API**: Access current market statistics

### Risk Management
- **User Reputation**: Track lending history and build trust scores
- **Default Tracking**: Monitor and penalize defaults with higher rates
- **Collateral Assessment**: Risk-adjusted pricing based on collateral type
- **Collection Risk Scores**: NFT collections rated for risk level

## Roadmap

- [x] **Multi-Asset Support**: STX, SIP-10 tokens, and NFT collateral
- [x] **Dynamic Interest Rates**: Algorithm-based rates with supply/demand and risk assessment
- [ ] **Auction System**: Time-based bidding mechanism with automatic settlement and reserve prices
- [ ] **Collaborative Lending**: Multi-lender loan pools with shared risk
- [ ] **Advanced Analytics**: Detailed market analysis and prediction tools
- [ ] **Cross-Chain Bridge**: Integration with other blockchain networks
- [ ] **Insurance Protocol**: Optional loan insurance for lenders
- [ ] **Yield Farming**: Rewards for platform liquidity providers
- [ ] **Governance Token**: Community-driven platform decisions
- [ ] **Mobile Application**: Native mobile app for iOS and Android
- [ ] **Institutional Features**: Large-scale lending tools for institutions

## 🤝 Contributing

We welcome contributions to improve FlexiLend! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 🔄 Migration Guide

For users of the previous version:
- Existing loan functionality remains unchanged
- New dynamic rate system is applied to new loans
- Users can now set maximum acceptable interest rates
- All existing loans continue to function with their original rates
- New risk assessment system tracks user history for better rates

## 📚 API Reference

### Dynamic Rate Functions

#### `get-dynamic-rate`
Calculate current dynamic interest rate for specific parameters.

**Parameters:**
- `asset-type`: Asset type (1=STX, 2=SIP-10)
- `asset-contract`: Token contract (optional, none for STX)
- `user`: Borrower address for risk assessment
- `collateral-type`: Collateral asset type
- `collateral-amount`: Amount of collateral in micro-units
- `loan-amount`: Requested loan amount in micro-units

**Returns:** Current dynamic interest rate in basis points

#### `get-asset-utilization`
Get real-time supply and demand data for an asset.

**Parameters:**
- `asset-type`: Asset type to query
- `asset-contract`: Token contract (optional)

**Returns:** Utilization data including supply, demand, and utilization rate

---

**Built with ❤️ on Stacks blockchain**

