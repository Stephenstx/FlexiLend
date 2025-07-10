# FlexiLend 🚀

A flexible peer-to-peer lending platform built on Stacks blockchain, enabling users to create custom loan terms and facilitating trustless lending with collateral management.

## 🎯 Overview

FlexiLend revolutionizes decentralized lending by allowing borrowers to set their own terms while ensuring lenders are protected through collateral requirements. The platform uses smart contracts to automate loan creation, funding, repayment, and liquidation processes.

## ✨ Key Features

- **Custom Loan Terms**: Borrowers can set their own interest rates and loan durations
- **Collateral Protection**: Minimum 150% collateral ratio ensures lender security
- **Automated Liquidation**: Overdue loans are automatically liquidated to protect lenders
- **Reputation System**: Track user lending history and build trust
- **Platform Fees**: Sustainable 2.5% fee structure for platform maintenance
- **Flexible Duration**: Loans can range from short-term to up to 1 year

## 🛠️ Technical Implementation

### Smart Contract Architecture

The FlexiLend smart contract is built using Clarity and includes:

- **Loan Management**: Create, fund, repay, and liquidate loans
- **Collateral Handling**: Automatic collateral lock and release
- **Interest Calculation**: Proportional interest based on loan duration
- **User Statistics**: Track lending history and reputation scores
- **Admin Controls**: Platform fee and parameter adjustments

### Key Functions

- `create-loan`: Create a new loan request with collateral
- `fund-loan`: Fund an existing loan request
- `repay-loan`: Repay a loan with interest
- `liquidate-loan`: Liquidate overdue loans
- `get-loan`: Retrieve loan details
- `get-user-stats`: View user lending statistics

## 📊 Platform Parameters

- **Minimum Collateral Ratio**: 150%
- **Platform Fee**: 2.5%
- **Maximum Loan Duration**: ~1 year (52,560 blocks)
- **Interest Rate Range**: 1% - 100% annually

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet with STX tokens
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Run `clarinet check` to verify contract syntax
3. Deploy to testnet using `clarinet integrate`

### Usage Example

```clarity
;; Create a loan requesting 1000 STX with 1500 STX collateral
;; 5% annual interest rate for 5256 blocks (~1 month)
(contract-call? .flexilend create-loan u1000000000 u1500000000 u500 u5256)

;; Fund the loan (as a lender)
(contract-call? .flexilend fund-loan u1)

;; Repay the loan (as borrower)
(contract-call? .flexilend repay-loan u1)
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
- Total loans created
- User lending history
- Reputation scores
- Platform fee collection
- Liquidation events

## 🔐 Security Features

- **Input Validation**: All parameters are validated before execution
- **Access Control**: Function-specific authorization checks
- **Collateral Protection**: Automatic collateral management
- **Overflow Protection**: Safe arithmetic operations
- **Error Handling**: Comprehensive error codes and messages

## 🤝 Contributing

We welcome contributions to improve FlexiLend! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

