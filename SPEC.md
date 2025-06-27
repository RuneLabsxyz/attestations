# Starknet Attestation System (SAS) Specification v1.0

## Overview

The Starknet Attestation System (SAS) is a decentralized attestation infrastructure for Starknet that enables anyone to create, register, and use schemas for making verifiable claims about any entity or data. Each schema is deployed as an autonomous smart contract that manages its own attestations, inspired by the ERC-20 standard's approach to metadata functions.

## Core Principles

1. **Decentralized**: Each schema contract is autonomous and manages its own attestations
2. **Standardized**: Common interface ensures interoperability while allowing custom logic
3. **Discoverable**: Simple registry system for schema discovery
4. **Composable**: Official extensions enable schema composition and dependencies
5. **Flexible**: Support for both stored ("external") and computed ("deterministic") attestations
6. **Modular**: Component-based architecture for common features

## Architecture Components

### 1. Schema Contract Standard

Every schema contract must implement the `ISchemaStandard` interface, following an ERC-20-like pattern for metadata:

```cairo
#[starknet::interface]
trait ISchemaStandard<TContractState> {
    // ===== METADATA FUNCTIONS (Required) =====
    /// Returns the human-readable name of the schema
    fn name(self: @TContractState) -> ByteArray;
    
    /// Returns a detailed description of what this schema attests to
    fn description(self: @TContractState) -> ByteArray;
    
    /// Returns the version number of this schema implementation
    fn version(self: @TContractState) -> u32;
    
    /// Returns the category for discovery (e.g., 'identity', 'reputation', 'skill')
    fn category(self: @TContractState) -> felt252;
    
    /// Returns a hash representing the expected data structure
    fn schema_hash(self: @TContractState) -> felt252;
    
    /// Returns whether this schema supports deterministic verification
    fn supports_deterministic(self: @TContractState) -> bool;
    
    /// Returns whether attestations from this schema can be revoked
    fn is_revocable(self: @TContractState) -> bool;
    
    // ===== CORE ATTESTATION FUNCTIONS (Required) =====
    /// Creates a new attestation and returns its unique ID
    fn create_attestation(ref self: TContractState, 
                         recipient: ContractAddress, 
                         data: Span<felt252>) -> felt252;
    
    /// Retrieves an attestation by its ID
    fn get_attestation(self: @TContractState, 
                      attestation_id: felt252) -> Option<AttestationData>;
    
    /// For deterministic schemas: verifies data without storing
    fn verify_deterministic(self: @TContractState, 
                           subject: ContractAddress, 
                           data: Span<felt252>) -> bool;
    
    // ===== QUERY FUNCTIONS (Required) =====
    /// Returns all attestation IDs for a given subject
    fn get_attestations_for(self: @TContractState, 
                           subject: ContractAddress) -> Array<felt252>;
    
    /// Returns the total number of attestations created
    fn attestation_count(self: @TContractState) -> u64;
    
    // ===== OPTIONAL FUNCTIONS =====
    /// Revokes an attestation (if schema supports revocation)
    fn revoke_attestation(ref self: TContractState, attestation_id: felt252);
    
    /// Returns all attestations created by a specific attester
    fn get_attestations_by(self: @TContractState, 
                          attester: ContractAddress) -> Array<felt252>;
}
```

### 2. Core Data Structures

```cairo
/// Standard attestation data structure
#[derive(Drop, Serde, starknet::Store)]
struct AttestationData {
    /// Unique identifier for this attestation
    id: felt252,
    /// Address that created the attestation
    attester: ContractAddress,
    /// Subject of the attestation
    recipient: ContractAddress,
    /// Schema-specific data payload
    data: Array<felt252>,
    /// When the attestation was created
    timestamp: u64,
    /// Whether this attestation has been revoked
    is_revoked: bool,
}

/// Registration metadata for the registry
#[derive(Drop, Serde, starknet::Store)]
struct RegistrationMetadata {
    /// When this schema was registered
    registration_time: u64,
    /// Who registered this schema
    registrar: ContractAddress,
}
```

### 3. Schema Registry Contract

The registry provides discovery and indexing services:

```cairo
#[starknet::interface]
trait ISchemaRegistry<TContractState> {
    // ===== REGISTRATION =====
    /// Register a new schema contract (anyone can register)
    fn register_schema(ref self: TContractState, schema_address: ContractAddress);
    
    /// Unregister a schema (only the registrar can unregister)
    fn unregister_schema(ref self: TContractState, schema_address: ContractAddress);
    
    // ===== DISCOVERY =====
    /// Find schemas by category
    fn get_schemas_by_category(self: @TContractState, 
                              category: felt252) -> Array<ContractAddress>;
    
    /// Get all registered schemas
    fn get_all_schemas(self: @TContractState) -> Array<ContractAddress>;
    
    /// Check if a schema is registered
    fn is_registered(self: @TContractState, 
                    schema_address: ContractAddress) -> bool;
    
    /// Get registration metadata
    fn get_registration_info(self: @TContractState, 
                            schema_address: ContractAddress) -> Option<RegistrationMetadata>;
    
    // ===== STATISTICS =====
    /// Total number of registered schemas
    fn total_schemas(self: @TContractState) -> u64;
    
    /// Get schemas registered by a specific address
    fn get_schemas_by_registrar(self: @TContractState, 
                               registrar: ContractAddress) -> Array<ContractAddress>;
}
```

### 4. Component Library

Reusable components for common attestation features:

#### Expiration Component
```cairo
#[starknet::component]
mod ExpirationComponent {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        /// Maps attestation ID to expiry timestamp (0 = no expiry)
        attestation_expiry: Map<felt252, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ExpirySet: ExpirySet,
    }

    #[derive(Drop, starknet::Event)]
    struct ExpirySet {
        attestation_id: felt252,
        expiry_time: u64,
    }

    #[embeddable_as(ExpirationImpl)]
    impl ExpirationImpl<TContractState, +HasComponent<TContractState>> 
        of IExpiration<ComponentState<TContractState>> {
        
        fn set_expiry(ref self: ComponentState<TContractState>, 
                     attestation_id: felt252, 
                     expiry: u64) {
            self.attestation_expiry.write(attestation_id, expiry);
            self.emit(ExpirySet { attestation_id, expiry_time: expiry });
        }
        
        fn get_expiry(self: @ComponentState<TContractState>, attestation_id: felt252) -> u64 {
            self.attestation_expiry.read(attestation_id)
        }
        
        fn is_expired(self: @ComponentState<TContractState>, attestation_id: felt252) -> bool {
            let expiry = self.attestation_expiry.read(attestation_id);
            expiry != 0 && starknet::get_block_timestamp() > expiry
        }
    }

    trait IExpiration<TComponentState> {
        fn set_expiry(ref self: TComponentState, attestation_id: felt252, expiry: u64);
        fn get_expiry(self: @TComponentState, attestation_id: felt252) -> u64;
        fn is_expired(self: @TComponentState, attestation_id: felt252) -> bool;
    }
}
```

#### Revocation Component
```cairo
#[starknet::component]
mod RevocationComponent {
    #[storage]
    struct Storage {
        /// Maps attestation ID to revocation status and reason
        revocations: Map<felt252, RevocationInfo>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct RevocationInfo {
        is_revoked: bool,
        revoked_by: ContractAddress,
        revocation_time: u64,
        reason: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AttestationRevoked: AttestationRevoked,
    }

    #[derive(Drop, starknet::Event)]
    struct AttestationRevoked {
        attestation_id: felt252,
        revoked_by: ContractAddress,
        reason: felt252,
    }

    #[embeddable_as(RevocationImpl)]
    impl RevocationImpl<TContractState, +HasComponent<TContractState>> 
        of IRevocation<ComponentState<TContractState>> {
        
        fn revoke(ref self: ComponentState<TContractState>, 
                 attestation_id: felt252, 
                 reason: felt252) {
            let revocation_info = RevocationInfo {
                is_revoked: true,
                revoked_by: starknet::get_caller_address(),
                revocation_time: starknet::get_block_timestamp(),
                reason,
            };
            
            self.revocations.write(attestation_id, revocation_info);
            self.emit(AttestationRevoked { 
                attestation_id, 
                revoked_by: revocation_info.revoked_by, 
                reason 
            });
        }
        
        fn is_revoked(self: @ComponentState<TContractState>, attestation_id: felt252) -> bool {
            self.revocations.read(attestation_id).is_revoked
        }
        
        fn get_revocation_info(self: @ComponentState<TContractState>, 
                              attestation_id: felt252) -> RevocationInfo {
            self.revocations.read(attestation_id)
        }
    }

    trait IRevocation<TComponentState> {
        fn revoke(ref self: TComponentState, attestation_id: felt252, reason: felt252);
        fn is_revoked(self: @TComponentState, attestation_id: felt252) -> bool;
        fn get_revocation_info(self: @TComponentState, attestation_id: felt252) -> RevocationInfo;
    }
}
```

### 5. Schema Composition Extension

For schemas that need to reference or depend on other schemas:

```cairo
#[starknet::interface]
trait ISchemaComposition<TContractState> {
    /// Returns schema addresses this schema depends on
    fn get_dependencies(self: @TContractState) -> Array<ContractAddress>;
    
    /// Validates an attestation that requires data from multiple schemas
    fn validate_composed(self: @TContractState, 
                        subject: ContractAddress, 
                        attestation_data: Array<ComposedData>) -> bool;
    
    /// Returns the minimum version required for each dependency
    fn get_dependency_requirements(self: @TContractState) -> Array<DependencyRequirement>;
}

#[derive(Drop, Serde)]
struct ComposedData {
    schema_address: ContractAddress,
    data: Span<felt252>,
}

#[derive(Drop, Serde)]
struct DependencyRequirement {
    schema_address: ContractAddress,
    min_version: u32,
    required: bool,  // true = hard dependency, false = optional
}
```

## Schema Versioning Strategies

### Strategy 1: In-Place Upgrades (Recommended)

```cairo
#[starknet::contract]
mod VersionedSchema {
    #[storage]
    struct Storage {
        implementation_version: u32,
        // ... other storage
    }
    
    #[abi(embed_v0)]
    impl VersionedImpl of super::ISchemaStandard<ContractState> {
        fn version(self: @ContractState) -> u32 {
            self.implementation_version.read()
        }
        
        fn create_attestation(ref self: ContractState, 
                             recipient: ContractAddress, 
                             data: Span<felt252>) -> felt252 {
            match self.implementation_version.read() {
                1 => self.create_attestation_v1(recipient, data),
                2 => self.create_attestation_v2(recipient, data),
                _ => panic_with_felt252('Unsupported version')
            }
        }
    }
    
    // Admin functions for upgrades
    #[abi(embed_v0)]
    impl UpgradeImpl of IUpgrade<ContractState> {
        fn upgrade_version(ref self: ContractState, new_version: u32) {
            self.ownable.assert_only_owner();
            assert(new_version > self.implementation_version.read(), 'Version must increase');
            self.implementation_version.write(new_version);
        }
    }
}
```

### Strategy 2: Migration Interface

```cairo
#[starknet::interface]
trait ISchemaMigration<TContractState> {
    /// Migrate attestations from an older version of this schema
    fn migrate_from(ref self: TContractState, 
                   old_schema: ContractAddress, 
                   attestation_ids: Array<felt252>);
    
    /// Get the address of the previous version (if any)
    fn get_predecessor(self: @TContractState) -> Option<ContractAddress>;
    
    /// Get the address of the next version (if any)
    fn get_successor(self: @TContractState) -> Option<ContractAddress>;
}
```

## Example Use Cases

### 1. Identity Verification Schema

**Purpose**: Verify user identity with different KYC levels
**Data Format**: `[name_hash: felt252, age_group: u8, kyc_level: u8, provider: ContractAddress]`

- **External Attestations**: KYC providers create stored attestations
- **Deterministic**: Real-time verification requires trusted provider + KYC level ≥ 3

### 2. Skill Verification Schema

**Purpose**: Attest to technical or professional skills
**Data Format**: `[skill_hash: felt252, level: u8, certification_hash: felt252, verifier: ContractAddress]`

- **External Attestations**: Educational institutions, employers, or certification bodies
- **Deterministic**: Check against trusted verifier registry

### 3. Reputation Schema

**Purpose**: Track reputation scores across different domains
**Data Format**: `[domain: felt252, score: u64, evidence_hash: felt252, endorser: ContractAddress]`

- **External Attestations**: Stored with evidence links
- **Deterministic**: Aggregate score calculation from multiple attestations

### 4. Governance Participation Schema

**Purpose**: Track participation in governance activities
**Data Format**: `[dao_address: ContractAddress, proposal_id: felt252, vote: u8, voting_power: u256]`

- **External Attestations**: DAO contracts create participation records
- **Deterministic**: Verify current voting eligibility

## System Flow

### Schema Creation and Registration
1. Developer deploys a schema contract implementing `ISchemaStandard`
2. Schema contract is registered with the central registry
3. Registry validates the interface and indexes by category
4. Schema is now discoverable and ready for use

### External Attestation Flow
1. Attester calls `create_attestation` on the schema contract
2. Schema validates data format and business logic
3. If valid, attestation is stored with unique ID
4. Events emitted for indexing and notifications

### Deterministic Attestation Flow
1. Verifier calls `verify_deterministic` on the schema contract
2. Schema performs real-time validation (may check external sources)
3. Boolean result returned immediately
4. No storage required, computation happens on-demand

### Registry Discovery Flow
1. User queries registry by category or searches all schemas
2. Registry returns list of schema contract addresses
3. User calls metadata functions on schema contracts
4. User selects appropriate schema and interacts directly

## Benefits

1. **True Decentralization**: Each schema is autonomous, no central authority
2. **Standard Interface**: ERC-20 style ensures predictable behavior
3. **Flexible Logic**: Schemas can implement any validation rules
4. **Composability**: Schemas can reference and build upon each other
5. **Upgradeability**: Multiple strategies for schema evolution
6. **Gas Efficiency**: Deterministic attestations avoid unnecessary storage
7. **Discoverability**: Registry enables easy schema discovery

## Migration Path

### Phase 1: Core Infrastructure
- Deploy registry contract
- Create component library with common features
- Develop example schema contracts
- Create basic tooling and documentation

### Phase 2: Schema Development
- Deploy reference implementations (identity, reputation, skills)
- Community creates domain-specific schemas
- Establish best practices and patterns

### Phase 3: Ecosystem Growth
- Build SDK and developer tools
- Create user interfaces for schema interaction
- Integrate with existing Starknet applications
- Enable cross-schema composition

### Phase 4: Advanced Features
- Implement advanced composition patterns
- Add privacy-preserving attestation options
- Create attestation aggregation and analysis tools
- Develop governance mechanisms for standard evolution

## Security Considerations

1. **Schema Contract Security**: Each schema must implement proper access controls
2. **Data Validation**: Schemas should validate all input data thoroughly
3. **Upgrade Safety**: Version upgrades should preserve data integrity
4. **Registry Security**: Registry should prevent malicious schema registration
5. **Component Security**: Shared components must be thoroughly audited

## Future Extensions

1. **Privacy-Preserving Attestations**: Zero-knowledge proofs for sensitive data
2. **Cross-Chain Attestations**: Bridge attestations between different networks
3. **Automated Oracles**: Schema contracts that automatically verify external data
4. **Attestation Markets**: Economic mechanisms for attestation creation and verification
5. **Advanced Queries**: Complex query language for attestation discovery

---

This specification provides the foundation for a flexible, decentralized attestation system that can grow and evolve with the needs of the Starknet ecosystem while maintaining backward compatibility and interoperability.