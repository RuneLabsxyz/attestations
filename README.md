# Starknet Attestation Standard

A comprehensive standard interface for creating, managing, and verifying attestations on Starknet. This repository contains the reference implementation of SNIP-XXX, providing a framework for identity verification, credential management, and trust establishment in decentralized applications.

## 🎯 Overview

Attestations are cryptographically verifiable statements about entities (users, contracts, or other addresses) that enable:

- **Identity Verification**: Prove ownership of accounts or credentials
- **Credential Management**: Issue and verify educational, professional, or social credentials
- **Trust Establishment**: Build reputation and trust networks
- **Composable Verification**: Chain attestations together for complex requirements

## ✨ Key Features

### 🔗 Composability First
- **Recursive Verification**: Attestations can reference and verify other attestations
- **Dependency Chains**: Build complex trust relationships
- **Modular Design**: Mix and match different attestation types

### 🛡️ Privacy Options
- **Public Attestations**: Full transparency when desired
- **Private Attestations**: Hash-based privacy preservation
- **Selective Disclosure**: Reveal only necessary information
- **Zero-Knowledge Ready**: Framework supports ZK proof integration

### 📋 Schema-Driven
- **Type Safety**: Structured data definitions with validation
- **Complex Types**: Support for enums, structs, and nested data
- **JSON Export**: Dynamic client configuration support
- **Versioning**: Schema evolution with backward compatibility

### 🔄 Interoperability
- **Standard Interface**: Common `IAttestation` interface for all implementations
- **Cross-Contract**: Attestations can verify attestations from other contracts
- **Extensible**: Easy to add new attestation types

## 🚀 Getting Started

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) - Cairo package manager
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) - Testing framework

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/starknet-attestations
cd starknet-attestations
```

2. Build the project:
```bash
scarb build
```

3. Run tests:
```bash
scarb test
```

## 📁 Project Structure

```
attestations/
├── src/
│   ├── lib.cairo              # Main library exports
│   ├── interfaces.cairo       # Core IAttestation interface
│   ├── types.cairo           # Schema types and utilities
│   └── implementation/
│       ├── discord_attestation.cairo  # Discord verification example
│       └── ...               # Other attestation types
├── SNIP-XXX.md              # Full specification document
├── Scarb.toml               # Project configuration
└── README.md                # This file
```

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
scarb test

# Run specific test file
scarb test tests/discord_attestation_test.cairo

# Run with verbose output
scarb test -v
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Run the test suite: `scarb test`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 🙏 Acknowledgments

- Starknet Foundation for the platform
- Cairo language team for the development tools
- Community contributors and reviewers
- OpenZeppelin for security best practices inspiration

---

**Built with ❤️ by RuneLabs for the Starknet ecosystem**
