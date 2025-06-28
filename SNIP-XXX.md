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
3. **Privacy Options**: Support for both public and privacy-preserving attestations
4. **Flexibility**: Extensible schema system for different attestation types
5. **Trust Management**: Built-in verification and validity management

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
    String,
    Uint256,
    Uint64,
    Address,
    Bool,
    Bytes,
    Hash,
    Enum,
    Struct,
}
```

### Enum and Struct Definitions

For complex data structures, schemas can define enums and structs:

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
    pub revoked: bool,
    pub revoked_at: Option<u64>,
    pub external_ref: Option<ByteArray>,
}
```

### Verification Logic

The `verify` function MUST implement the following checks:

1. **Existence**: Attestation must exist (non-zero ID)
2. **Validity**: Attestation must not be marked as invalid/revoked

Additional validation logic MAY be implemented through optional components (e.g., expiration checks, dependency verification, programmatic validity checks).

### Composability

Attestations are designed to be composable. The `verify` function enables recursive verification patterns where attestations can build upon other attestations:

#### Recursive Verification
Attestations can reference other attestations by ID and use the Starknet interface dispatcher to call the `verify()` function on sub-contracts. This enables:

1. **Chaining**: Attestations can reference prerequisite attestations
2. **Dependency Resolution**: Complex attestations can verify multiple requirement attestations
3. **Programmatic Validity**: Dynamic checks (e.g., verifying NFT ownership for attestation validity)

#### Schema Enhancement and Combination
Schemas can be enhanced and combined in various ways:

- **Multi-Attestation Requirements**: An attestation that requires both a Discord verification AND an age verification to be valid
- **Layered Attestations**: A "Verified Developer" attestation that requires a GitHub attestation, educational credential attestation, and portfolio attestation
- **Conditional Attestations**: Attestations that remain valid only while underlying conditions are met (e.g., membership status, asset ownership)

#### Binary Decision Making
Multiple attestations can be combined to reach final verification outcomes:

```cairo
// Example: Composite verification logic
fn verify_composite(
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

Additional events MAY be emitted for other state changes (e.g., revocation).

### JSON Schema Export

The `get_schema_json` function MUST return a valid JSON representation of the schema. This is mandatory to enable dynamic client configurations. The JSON MUST follow this structure:

```json
{
  "name": "Schema Name",
  "description": "Schema description",
  "version": 1,
  "fields": [
    {
      "name": "field_name",
      "type": "FieldType",
      "required": true,
      "size": 0,
      "description": "Field description"
    }
  ]
}
```

#### Enhanced JSON Schema for Enums

For enum fields, the JSON MUST include variant definitions:

```json
{
  "name": "data",
  "type": "Enum",
  "required": true,
  "size": 0,
  "description": "Tagged union data",
  "variants": [
    {
      "name": "VariantA",
      "description": "First variant",
      "fields": [
        {
          "name": "field1",
          "type": "String",
          "required": true
        }
      ]
    },
    {
      "name": "VariantB",
      "description": "Second variant",
      "fields": [
        {
          "name": "field2",
          "type": "Uint64",
          "required": true
        }
      ]
    }
  ]
}
```

#### Enhanced JSON Schema for Structs

For struct fields, the JSON MUST include struct definitions:

```json
{
  "name": "location",
  "type": "Struct",
  "required": true,
  "size": 0,
  "description": "Location data",
  "struct": {
    "name": "Point",
    "description": "2D coordinate point",
    "fields": [
      {
        "name": "x",
        "type": "Uint64",
        "required": true,
        "description": "X coordinate"
      },
      {
        "name": "y",
        "type": "Uint64",
        "required": true,
        "description": "Y coordinate"
      }
    ]
  }
}
```

## Implementation Guidelines

### Privacy Considerations

Implementations MAY support privacy-preserving attestations by:

1. Using hash-based proofs instead of raw data
2. Implementing selective disclosure mechanisms
3. Supporting zero-knowledge proof integration with tools like Noir or other ZK frameworks
4. Providing privacy-preserving verification methods

### Access Control

Implementations SHOULD implement appropriate access control for:

1. **Creation**: Who can create attestations
2. **Revocation**: Who can mark attestations as invalid
3. **Reading**: Whether attestation data is public or restricted

### Gas Optimization

Implementations SHOULD optimize for gas efficiency by:

1. Using efficient storage patterns
2. Minimizing external calls in verification
3. Batching operations where possible
4. Caching verification results when appropriate for composite attestations

### Optional Components

Implementations MAY include optional components for:

1. **Expiration Management**: Time-based validity checks
2. **Dependency Verification**: Automatic checking of prerequisite attestations
3. **Audit Trails**: Enhanced logging and history tracking
4. **Programmatic Validity**: Dynamic verification based on external state

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

Implementations SHOULD use unique attestation IDs to prevent replay attacks.

### Data Integrity

Attestation data MUST be immutable once created to maintain integrity. The only exception is the validity state, which can transition from valid to invalid in one direction only. Once an attestation is marked as invalid, it cannot be made valid again.

This one-way validity transition provides:
- **Consistency**: Clients and indexers can rely on state consistency
- **Simplicity**: No complex state management required
- **Trust**: Clear audit trails for validity changes

If underlying conditions change (e.g., NFT ownership for programmatic validity), a new attestation must be created rather than reverting the invalid state.

### Access Control

Proper access control MUST be implemented to prevent unauthorized attestations and revocations.

### Composability Security

When implementing composite attestations:
- Verify all dependency contracts implement this standard
- Implement circuit breakers for recursive verification depth
- Consider gas limits when chaining multiple verifications
- Validate attestation IDs exist before making external calls

### Privacy Leakage

When implementing privacy-preserving attestations:
- Zero-knowledge proof integration for enhanced privacy
- Selective disclosure mechanisms to reveal only necessary information
- Hash-based verification to avoid exposing raw data
- Consider metadata leakage through transaction patterns

Note: Traditional concerns about timing attacks and side channels through execution timing are not applicable in blockchain environments where all execution is deterministic and publicly verifiable.

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
