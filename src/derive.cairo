//! Derive-like utilities for automatically generating ABIProvider implementations
//!
//! This module provides a simple way to generate ABIProvider implementations
//! without complex macros, using a derive-like pattern that works with Cairo.

use starknet::ContractAddress;
use super::{ABIField, StructABI, ABIProvider};

/// Derive-like utility for AttestationData structs
pub fn derive_attestation_abi<T, +Serde<T>>(
    struct_name: ByteArray,
    field_definitions: Array<(ByteArray, ByteArray, u32)>
) -> impl ABIProvider<T> {
    DerivedABIProvider {
        struct_name,
        field_definitions,
    }
}

/// Generated ABI provider implementation
pub struct DerivedABIProvider<T> {
    struct_name: ByteArray,
    field_definitions: Array<(ByteArray, ByteArray, u32)>,
}

impl<T, +Serde<T>> ABIProvider<T> for DerivedABIProvider<T> {
    fn get_abi(self: @DerivedABIProvider<T>) -> StructABI {
        let mut fields = array![];
        let mut total_size = 0;

        let mut i = 0;
        loop {
            if i >= self.field_definitions.len() {
                break;
            }

            let (name, field_type, size) = self.field_definitions.at(i);
            total_size += *size;

            fields.append(ABIField {
                name: name.clone(),
                field_type: field_type.clone(),
                size_bytes: *size,
            });

            i += 1;
        };

        StructABI {
            name: self.struct_name.clone(),
            fields,
            total_size,
        }
    }

    fn get_field_count(self: @DerivedABIProvider<T>) -> u32 {
        self.field_definitions.len()
    }

    fn serialize_to_array(self: @DerivedABIProvider<T>, instance: T) -> Array<felt252> {
        let mut serialized = array![];
        instance.serialize(ref serialized);
        serialized
    }
}

/// Convenient derive function for standard attestation structs
pub fn derive_standard_attestation<T, +Serde<T>>() -> impl ABIProvider<T> {
    derive_attestation_abi::<T>(
        "AttestationData",
        array![
            ("attester", "ContractAddress", 32),
            ("subject", "ContractAddress", 32),
            ("schema_id", "felt252", 32),
            ("data", "ByteArray", 0),
            ("timestamp", "u64", 8),
            ("expiration", "u64", 8),
            ("revocable", "bool", 1),
            ("ref_attestation", "felt252", 32),
        ]
    )
}

/// Derive function for identity verification attestations
pub fn derive_identity_attestation<T, +Serde<T>>() -> impl ABIProvider<T> {
    derive_attestation_abi::<T>(
        "IdentityAttestation",
        array![
            ("attester", "ContractAddress", 32),
            ("subject", "ContractAddress", 32),
            ("identity_hash", "felt252", 32),
            ("verification_level", "u64", 8),
            ("document_type", "felt252", 32),
            ("timestamp", "u64", 8),
            ("expiration", "u64", 8),
            ("is_verified", "bool", 1),
        ]
    )
}

/// Derive function for reputation attestations
pub fn derive_reputation_attestation<T, +Serde<T>>() -> impl ABIProvider<T> {
    derive_attestation_abi::<T>(
        "ReputationAttestation",
        array![
            ("attester", "ContractAddress", 32),
            ("subject", "ContractAddress", 32),
            ("reputation_score", "u64", 8),
            ("category", "felt252", 32),
            ("evidence_hash", "felt252", 32),
            ("weight", "u64", 8),
            ("timestamp", "u64", 8),
            ("is_positive", "bool", 1),
        ]
    )
}

/// Builder pattern for custom derive functions
pub struct DeriveBuilder {
    struct_name: ByteArray,
    fields: Array<(ByteArray, ByteArray, u32)>,
}

impl DeriveBuilder {
    pub fn new(struct_name: ByteArray) -> DeriveBuilder {
        DeriveBuilder {
            struct_name,
            fields: array![],
        }
    }

    pub fn add_field(mut self: DeriveBuilder, name: ByteArray, type_name: ByteArray, size: u32) -> DeriveBuilder {
        self.fields.append((name, type_name, size));
        self
    }

    pub fn contract_address(self: DeriveBuilder, name: ByteArray) -> DeriveBuilder {
        self.add_field(name, "ContractAddress", 32)
    }

    pub fn felt252(self: DeriveBuilder, name: ByteArray) -> DeriveBuilder {
        self.add_field(name, "felt252", 32)
    }

    pub fn u64(self: DeriveBuilder, name: ByteArray) -> DeriveBuilder {
        self.add_field(name, "u64", 8)
    }

    pub fn u256(self: DeriveBuilder, name: ByteArray) -> DeriveBuilder {
        self.add_field(name, "u256", 32)
    }

    pub fn bool(self: DeriveBuilder, name: ByteArray) -> DeriveBuilder {
        self.add_field(name, "bool", 1)
    }

    pub fn byte_array(self: DeriveBuilder, name: ByteArray) -> DeriveBuilder {
        self.add_field(name, "ByteArray", 0)
    }

    pub fn build<T, +Serde<T>>(self: DeriveBuilder) -> impl ABIProvider<T> {
        derive_attestation_abi::<T>(self.struct_name, self.fields)
    }
}

/// Attribute-like derive function using function call syntax
pub fn derive<T, +Serde<T>>(struct_name: ByteArray) -> DeriveBuilder {
    DeriveBuilder::new(struct_name)
}

/// Usage examples
pub mod examples {
    use super::*;
    use starknet::ContractAddress;

    /// Example custom attestation struct
    #[derive(Drop, Serde, Clone, PartialEq)]
    pub struct CustomAttestation {
        pub issuer: ContractAddress,
        pub holder: ContractAddress,
        pub credential_type: felt252,
        pub score: u64,
        pub timestamp: u64,
        pub is_active: bool,
    }

    /// Example of how to use the derive function
    pub fn example_usage() {
        // Create a derived ABI provider for CustomAttestation
        let abi_provider = derive::<CustomAttestation>("CustomAttestation")
            .contract_address("issuer")
            .contract_address("holder")
            .felt252("credential_type")
            .u64("score")
            .u64("timestamp")
            .bool("is_active")
            .build();

        // Get the ABI
        let abi = abi_provider.get_abi();

        // Create a sample instance
        let attestation = CustomAttestation {
            issuer: starknet::contract_address_const::<0x123>(),
            holder: starknet::contract_address_const::<0x456>(),
            credential_type: 'education',
            score: 95,
            timestamp: 1703980800,
            is_active: true,
        };

        // Serialize it
        let serialized = abi_provider.serialize_to_array(attestation);
    }

    /// Example using standard attestation derive
    pub fn standard_example() {
        use super::super::AttestationData;

        let abi_provider = derive_standard_attestation::<AttestationData>();
        let abi = abi_provider.get_abi();

        // Use the ABI as needed
        assert(abi.name == "AttestationData", 'Wrong struct name');
        assert(abi.fields.len() == 8, 'Wrong field count');
    }
}

/// Convenience macro-like functions for common patterns
pub mod macros {
    use super::*;

    /// Simulate #[derive(Attestation)] behavior
    pub fn derive_attestation<T, +Serde<T>>(struct_name: ByteArray) -> impl ABIProvider<T> {
        derive_standard_attestation::<T>()
    }

    /// Simulate #[derive(IdentityAttestation)] behavior
    pub fn derive_identity<T, +Serde<T>>(struct_name: ByteArray) -> impl ABIProvider<T> {
        derive_identity_attestation::<T>()
    }

    /// Simulate #[derive(ReputationAttestation)] behavior
    pub fn derive_reputation<T, +Serde<T>>(struct_name: ByteArray) -> impl ABIProvider<T> {
        derive_reputation_attestation::<T>()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::examples::CustomAttestation;

    #[test]
    fn test_derive_builder() {
        let abi_provider = derive::<CustomAttestation>("CustomAttestation")
            .contract_address("issuer")
            .contract_address("holder")
            .felt252("credential_type")
            .u64("score")
            .u64("timestamp")
            .bool("is_active")
            .build();

        let abi = abi_provider.get_abi();
        assert(abi.name == "CustomAttestation", 'Wrong struct name');
        assert(abi.fields.len() == 6, 'Wrong field count');
        assert(abi_provider.get_field_count() == 6, 'Wrong field count method');
    }

    #[test]
    fn test_standard_derive() {
        use super::super::AttestationData;

        let abi_provider = derive_standard_attestation::<AttestationData>();
        let abi = abi_provider.get_abi();

        assert(abi.name == "AttestationData", 'Wrong struct name');
        assert(abi.fields.len() == 8, 'Wrong field count');
    }

    #[test]
    fn test_serialization() {
        let attestation = CustomAttestation {
            issuer: starknet::contract_address_const::<0x123>(),
            holder: starknet::contract_address_const::<0x456>(),
            credential_type: 'test',
            score: 100,
            timestamp: 1703980800,
            is_active: true,
        };

        let abi_provider = derive::<CustomAttestation>("CustomAttestation")
            .contract_address("issuer")
            .contract_address("holder")
            .felt252("credential_type")
            .u64("score")
            .u64("timestamp")
            .bool("is_active")
            .build();

        let serialized = abi_provider.serialize_to_array(attestation);
        assert(serialized.len() > 0, 'Serialization failed');
    }
}
