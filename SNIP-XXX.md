---
snip: XXX
title: Starknet Attestation Standard
description: A standard interface for creating, managing, and verifying attestations on Starknet
author: [Author Name] <email@example.com>
discussions-to: https://github.com/starknet-io/SNIPs/discussions/XXX
status: Draft
type: Standards Track
category: Interface
created: 2024-XX-XX
---

## Abstract

This SNIP defines a standard interface for attestations on Starknet. An attestation is a cryptographically verifiable statement about an entity, providing a framework for identity verification, credential management, and trust establishment in decentralized applications.

## Motivation

Decentralized applications often need to verify claims about users, contracts, or other entities. Current solutions are fragmented and lack interoperability. This standard provides:

1. **Interoperability**: A common interface for all attestation types
2. **Composability**: Attestations can reference and build upon other attestations
3. **Privacy Options**: Due to its free schema system, privacy-preserving attestations are supported, in the same way as fully-fledged ones.

## Specification

### Core Interface

All attestation contracts MUST implement the `IAttestation` interface:

```cairo
#[starknet::interface]
pub trait IAttestation<TContractState> {
    /// Returns the schema definition as a structured type
    fn get_schema(self: @TContractState) -> AttestationSchema;

    /// Returns the schema definition as a JSON string
    fn get_schema_json(self: @TContractState) -> ByteArray;

    /// Verifies if an attestation is valid and not revoked
    fn verify(self: @TContractState, attestation_id: felt252) -> bool;

    /// Gets attestation data by ID (returns generic felt252 array)
    fn get_attestation_data(self: @TContractState, attestation_id: felt252) -> Span<felt252>;

    /// Gets attestation IDs for a specific subject
    fn get_subject_attestations(self: @TContractState, subject: ContractAddress) -> Array<felt252>;
}
```

### Schema Definition

Attestation schemas MUST follow this structure:

```cairo
#[derive(Drop, Serde)]
pub struct AttestationSchema {
    pub name: ByteArray,
    pub description: ByteArray,
    pub version: u32,
    pub fields: Array<SchemaField>,
}


#[derive(Drop, Serde)]
pub struct SchemaField {
    pub name: ByteArray,
    pub field_type: FieldType,
    pub required: bool,
    pub size: u32,
    pub description: ByteArray,
    pub enum_variants: Option<Array<EnumVariant>>,
    pub struct_definition: Option<StructDefinition>,
}
```

### Supported Field Types

The following field types MUST be supported:

```cairo
#[derive(Drop, Serde, Clone, Copy)]
pub enum FieldType {
    ShortString,
    String,

    Uint64,
    Uint128,
    Uint256,

    Int64,
    Int128,
    Int256,

    ContractAddress,
    Bool,
    Bytes,
    Enum,
    Struct,
}
```

The current specification explicitly doesn't specify the integer and unsigned below 64 to simplify the implementation of attestation systems at the moment.

No automatic generation of the schema fields is currently supported, but implementors MAY automatically generate the schema fields from the struct definition in the contract.

### Enum and Struct Definitions

For complex nested data structures, schemas can define enums and structs:

```cairo
#[derive(Drop, Serde)]
pub struct EnumVariant {
    pub name: ByteArray,
    pub description: ByteArray,
    pub fields: Array<SchemaField>,
}

#[derive(Drop, Serde)]
pub struct StructDefinition {
    pub name: ByteArray,
    pub description: ByteArray,
    pub fields: Array<SchemaField>,
}
```

#### Enum Fields
When `field_type` is `FieldType::Enum`, the `enum_variants` field MUST contain an array of `EnumVariant` definitions. Each variant can contain its own set of fields, enabling tagged union types.

#### Struct Fields
When `field_type` is `FieldType::Struct`, the `struct_definition` field MUST contain a `StructDefinition` with the struct's field definitions.

### Core Attestation Structure

The base attestation structure SHOULD follow this pattern:

```cairo
#[derive(Drop, Serde)]
pub struct Attestation<TData> {
    pub id: felt252,
    pub subject: ContractAddress,
    pub data: TData,
    pub created_at: u64,
}
```

### Verification Logic

The `verify` function MUST implement the following checks:

1. **Existence**: Attestation must exist (non-zero ID)
2. **Validity**: Attestation must not be marked as invalid/revoked

Additional validation logic MAY be implemented through optional components (e.g., expiration checks, dependency verification, programmatic validity checks).

If some additional validation logic is implement, the components MUST respect the following rules:

1. **Decisiveness**: Once an attestation is refused through the `verify` function once, the implementor MUST always return false for that given attestation.


The above requirements ensure the simplicity of the indexing systems, along with the on-chain users of the specification.

### Composability

Attestations are designed to be composable. The `verify` function enables recursive verification patterns where attestations can build upon other attestations:

#### Recursive Verification
Attestations can reference other attestations by ID and use the Starknet interface dispatcher to call the `verify()` function on sub-contracts. This enables:

1. **Chaining**: Attestations can reference prerequisite attestations
2. **Dependency Resolution**: Complex attestations can verify multiple requirement attestations
3. **Programmatic Validity**: Dynamic checks (e.g., verifying NFT ownership for attestation validity)

#### Schema Enhancement and Combination
Schemas can be enhanced and combined in various ways:

- **Multi-Attestation Requirements**: For example, an attestation that requires both a Discord verification AND an age verification to be valid
- **Layered Attestations**: A "Verified Developer" attestation that requires a GitHub attestation, educational credential attestation, and portfolio attestation
- **Conditional Attestations**: Attestations that remain valid only while underlying conditions are met (e.g., membership status, asset ownership)

#### Binary Decision Making
Multiple attestations can be combined to reach final verification outcomes:

```cairo
// Example: Composite verification logic
fn verify(
    self: @ContractState,
    attestation_id: felt252
) -> bool {
    let attestation = self.get_attestation(attestation_id);

    // Verify this attestation is not revoked
    if attestation.revoked {
        return false;
    }

    // Verify prerequisite attestations using dispatcher
    let github_dispatcher = IAttestationDispatcher {
        contract_address: attestation.github_contract
    };
    let education_dispatcher = IAttestationDispatcher {
        contract_address: attestation.education_contract
    };

    github_dispatcher.verify(attestation.github_attestation_id) &&
    education_dispatcher.verify(attestation.education_attestation_id)
}
```

This composability is a core objective of the system, enabling complex trust relationships and verification chains.

### Creating an Attestation

While the specification doesn't put a hard requirement on the initial attestation (without any dependencies on other attestations), implementations that does take dependencies SHOULD follow the composability guidelines on attestation creation:

- Have any specific parameters in first position
- Take a `Vec<(ContractAddress, felt252)>` as the last parameter, containing the dependencies, as required by the contract. Implementors SHOULD allow for any ordering of the dependencies, unless there are specific requirements.

> Reasoning: If not using a vec, especially with dynamic requirements, there are no easy way to differentiate between the requested attestation dependencies.

### Events

Implementations MUST emit the `AttestationCreated` event:

```cairo
#[derive(Drop, starknet::Event)]
pub struct AttestationCreated {
    pub attestation_id: felt252,
    pub subject: ContractAddress,
    pub created_at: u64,
}
```

Additional events MAY be emitted for other state changes (e.g., revocation), but are implementation-specific.

## Rationale

### Schema-Based Design

The schema-based approach provides:
- **Type Safety**: Clear data structure definitions with support for complex types
- **Validation**: Built-in field validation for primitives, enums, and structs
- **Documentation**: Self-documenting attestation types with nested type definitions
- **Evolution**: Version-controlled schema updates
- **Expressiveness**: Support for tagged unions (enums) and structured data (structs)
- **Composability**: Nested types enable complex data modeling

### Composability-First Design

The composability focus enables:
- **Modular Verification**: Build complex verification logic from simple components
- **Interoperability**: Different attestation types can work together seamlessly
- **Extensibility**: New attestation types can leverage existing ones
- **Scalability**: Verification logic can be distributed across multiple contracts
- **Trust Chains**: Establish complex trust relationships through attestation dependencies

### Privacy Options

Supporting both public and private attestations enables:
- **Transparency**: When full disclosure is desired
- **Privacy**: When selective disclosure is needed
- **Compliance**: Meeting different regulatory requirements
- **Zero-Knowledge Integration**: Future-proofing for advanced privacy solutions

## Backwards Compatibility

This is a new standard with no backwards compatibility concerns.

## Security Considerations

### Replay Attacks

Implementations SHOULD prefer using hash-based verification to prevent replay attacks, and conflict resolution, but all users of the attestation system MUST allow for any ID assignment system.

### Access Control

Proper access control MUST be implemented to prevent unauthorized attestations and revocations, for the implementations that requires them.

### Composability Security

When implementing composite attestations:
- Verify all dependency contracts implement this standard
- Implement circuit breakers for recursive verification depth
- Consider gas limits when chaining multiple verifications
- Validate attestation IDs exist before making external calls
- Sanitize, or implement a whitelist of the external contract addresses to prevent potential attacks.

### Privacy Leakage

When implementing privacy-preserving attestations:
- Zero-knowledge proof integration for enhanced privacy
- Selective disclosure mechanisms to reveal only necessary information
- Hash-based verification to avoid exposing raw data
- Consider metadata leakage through transaction patterns

Note: Traditional concerns about timing attacks and side channels through execution timing are not applicable in blockchain environments where all execution is deterministic and publicly verifiable.
