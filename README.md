# Carbon Credits Blockchain Platform

A blockchain-based system for tokenizing, issuing, trading, and retiring carbon credits with proper verification, certification, and marketplace functionality.

## Overview

This platform provides a robust framework for managing the lifecycle of carbon credits on the blockchain. By leveraging Ethereum's ERC-1155 token standard, the system enables transparent tracking of carbon credit projects and their associated credits while ensuring proper certification and verification.

## Key Components

The platform consists of three main smart contracts:

### 1. CarbonCredits Contract

This core contract handles the tokenization of carbon credits using the ERC-1155 standard.

**Key Features:**
- **Project Management**: Create, verify, and track carbon offset projects
- **Credit Issuance**: Issue carbon credits for verified projects
- **Credit Retirement**: Permanently retire credits to claim their environmental benefit
- **Role-Based Access Control**: Separate issuer and verifier roles for proper checks and balances

### 2. CarbonCreditMarketplace Contract

This contract enables trading of carbon credits using stablecoins (USDC and USDT).

**Key Features:**
- **Listings**: Verified sellers can list carbon credits for sale
- **Purchases**: Buyers can purchase credits using stablecoins
- **Fee Management**: Configurable platform fees for sustainability
- **Seller Verification**: Ensures only authorized entities can sell credits

### 3. CarbonCreditRegistry Contract

This contract manages certification information for carbon credit projects.

**Key Features:**
- **Certification Management**: Track certifications from recognized standards bodies
- **Certifier Authorization**: Only authorized entities can issue certifications
- **Certification Verification**: Verify the authenticity of project certifications
- **Revocation Tracking**: Track revoked certifiers for enhanced security

## Technical Architecture

```
┌────────────────────┐      ┌─────────────────────────┐      ┌───────────────────┐
│                    │      │                         │      │                   │
│   CarbonCredits    │◄────►│  CarbonCreditRegistry   │      │ CarbonCredit      │
│   (ERC-1155)       │      │                         │      │ Marketplace       │
│                    │      │                         │      │                   │
└────────────────────┘      └─────────────────────────┘      └───────────────────┘
         ▲                                                            ▲
         │                                                            │
         │                                                            │
         │                                                            │
         ▼                                                            ▼
┌────────────────────┐                                     ┌────────────────────┐
│                    │                                     │                    │
│  Project Issuers   │                                     │  Stablecoins       │
│  and Verifiers     │                                     │  (USDC/USDT)       │
│                    │                                     │                    │
└────────────────────┘                                     └────────────────────┘
```

## Roles and Permissions

The system implements role-based access control:

1. **Issuer Role**: Can create projects and issue carbon credits
2. **Verifier Role**: Can verify projects to enable credit issuance
3. **Admin Role**: Can manage marketplace settings and verified sellers
4. **Verified Seller Role**: Can list carbon credits for sale on the marketplace
5. **Registry Owner**: Can authorize and revoke certifiers
6. **Certifiers**: Can issue certifications for carbon credit projects

## Contract Interactions

- **Project Creation**: Issuers create carbon credit projects with metadata
- **Project Verification**: Verifiers approve legitimate projects
- **Credit Issuance**: Issuers mint carbon credit tokens for verified projects
- **Certification**: Authorized certifiers add standards certifications
- **Marketplace Listing**: Verified sellers list credits for sale
- **Credit Purchase**: Users buy credits with stablecoins
- **Credit Retirement**: Credit owners permanently retire credits for offset claims

## Workflow Example

1. An issuer creates a new carbon project (e.g., reforestation project)
2. A verifier checks and verifies the project
3. The issuer mints carbon credit tokens for the verified project
4. A certifier adds certification information from a standards body
5. The project owner lists credits for sale on the marketplace
6. A buyer purchases credits using USDC or USDT
7. The buyer can retire credits to claim the environmental benefit

## Security Features

- **Role-Based Authorization**: Ensures proper separation of duties
- **Reentrancy Protection**: Prevents reentrancy attacks on marketplace transactions
- **Certification Verification**: Validates the authenticity of certifiers
- **Certifier Revocation Tracking**: Tracks revoked certifiers for enhanced security
- **Fee Limits**: Caps platform fees to prevent excessive charges

## Technical Details

### Technology Stack

- **Smart Contract Language**: Solidity ^0.8.20
- **Token Standard**: ERC-1155 (Multi-token standard)
- **Access Control**: OpenZeppelin Access Control
- **Dependencies**:
  - OpenZeppelin Contracts for security best practices
  - Custom interfaces for cross-contract communication
  - SafeERC20 for secure token transfers

### Key Data Structures

- **Project**: Stores metadata about carbon projects
- **CreditBatch**: Represents a batch of carbon credits with specific attributes
- **Listing**: Marketplace listing with pricing and payment details
- **Certification**: Records certification data for projects

## Future Enhancements

- Integration with real-world carbon credit verification oracles
- Support for additional payment tokens
- Enhanced reporting and analytics
- Carbon credit bundling and derivatives
- Integration with decentralized exchanges for increased liquidity
- Governance mechanisms for decentralized platform management

## Getting Started

### Installation

Clone the repository and install Foundry:

```bash
# Clone the repository
git clone https://github.com/yourusername/carbon-credits-platform.git
cd carbon-credits-platform

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Create a `.env` file for environment variables:

```
PRIVATE_KEY=your_private_key_here
RPC_URL_MAINNET=your_mainnet_rpc_url
RPC_URL_SEPOLIA=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Compilation

Compile the smart contracts:

```bash
forge build
```

### Testing

Run the test suite:

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/CarbonCredits.t.sol

# Run with verbose output
forge test -vvv

# Run with gas reporting
forge test --gas-report

# Run test coverage
forge coverage
```

### Deployment

Deploy contracts to various networks:

```bash
# Deploy to local Anvil node
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (Sepolia)
forge script script/Deploy.s.sol --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY --broadcast --verify

# Deploy to mainnet
forge script script/Deploy.s.sol --rpc-url $RPC_URL_MAINNET --private-key $PRIVATE_KEY --broadcast --verify
```

## Acknowledgments

- Built with OpenZeppelin libraries for security best practices
- Inspired by existing carbon credit registry standards like Verra and Gold Standard