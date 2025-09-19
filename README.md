# 🗂️ Studypot - Learning Token Pool

A decentralized platform for collective funding of study resources, built on the Stacks blockchain using Clarity smart contracts.

## Overview

Studypot enables communities to pool funds together to purchase and share educational resources. Members contribute STX tokens to the pool and collectively decide on study materials to purchase, creating a collaborative learning ecosystem.

## Features

### Core Functionality
- **Collective Funding**: Members contribute STX tokens to a shared pool
- **Democratic Governance**: Community voting on resource purchases
- **Resource Sharing**: Purchased materials are accessible to all contributors
- **Transparent Management**: All transactions and decisions recorded on-chain
- **Flexible Contributions**: Members can contribute any amount above the minimum threshold

### Smart Contract Architecture
- **StudypotPool Contract**: Manages the main funding pool and member contributions
- **StudypotGovernance Contract**: Handles voting and resource purchasing decisions

## How It Works

1. **Join the Pool**: Members contribute STX tokens to become active participants
2. **Propose Resources**: Any member can propose educational materials to purchase
3. **Community Voting**: Members vote on proposed resources using their contribution weight
4. **Purchase & Share**: Approved resources are purchased and made available to all members
5. **Transparent Tracking**: All activities are recorded on the blockchain

## Technical Details

### Contracts
- `studypot-pool.clar`: Main pool management and contribution handling
- `studypot-governance.clar`: Voting mechanisms and resource approval

### Key Functions
- Member registration and contribution management
- Proposal submission and voting
- Pool balance tracking
- Resource purchase execution
- Contribution weight calculation

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Access to a Stacks blockchain node
- Web3-compatible browser

### Installation
```bash
git clone <repository-url>
cd studypot
clarinet check
npm install
npm test
```

### Testing
```bash
clarinet check
npm test
```

## Contributing

We welcome contributions to improve the Studypot platform. Please feel free to submit issues and enhancement requests.

## License

This project is open source and available under the MIT License.

## Support

For questions and support, please open an issue in the repository.

---

Built with ❤️ for the learning community using Stacks and Clarity.
