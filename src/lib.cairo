//! Attestation ABI Library
//!
//! This library provides utilities for working with attestation data structures
//! and extracting their ABI information for serialization purposes.

use starknet::ContractAddress;

pub mod contract;
pub mod codegen;
pub mod derive;

/// Attestation data structure that can be serialized
/// This represents a basic attestation with common fields
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct AttestationData {
    /// The subject being attested to
    pub subject: ContractAddress,
    /// Schema identifier for the attestation type
    pub schema_id: felt252,
    /// The actual attestation data payload
    pub data: ByteArray,
    /// Timestamp when the attestation was created
    pub timestamp: u64,
    /// Expiration timestamp (0 means no expiration)
    pub expiration: u64,
    /// Whether the attestation can be revoked
    pub revocable: bool,
    /// Reference to related attestation (0 means no reference)
    pub ref_attestation: felt252,
}

/// ABI field information
#[derive(Drop, Serde, Clone)]
pub struct ABIField {
    pub name: ByteArray,
    pub field_type: ByteArray,
    pub size_bytes: u32,
}

/// Complete ABI information for a struct
#[derive(Drop, Serde, Clone)]
pub struct StructABI {
    pub name: ByteArray,
    pub fields: Array<ABIField>,
    pub total_size: u32,
}

/// Trait for types that can provide their ABI information
pub trait ABIProvider<T> {
    fn get_abi() -> StructABI;
    fn get_field_count() -> u32;
    fn serialize_to_array(self: T) -> Array<felt252>;
}

/// Implementation of ABIProvider for AttestationData
impl AttestationDataABIProvider of ABIProvider<AttestationData> {
    fn get_abi() -> StructABI {
        let mut fields = array![];

        fields.append(ABIField {
            name: "subject",
            field_type: "ContractAddress",
            size_bytes: 32,
        });

        fields.append(ABIField {
            name: "schema_id",
            field_type: "felt252",
            size_bytes: 32,
        });

        fields.append(ABIField {
            name: "data",
            field_type: "ByteArray",
            size_bytes: 0, // Variable size
        });

        fields.append(ABIField {
            name: "timestamp",
            field_type: "u64",
            size_bytes: 8,
        });

        fields.append(ABIField {
            name: "expiration",
            field_type: "u64",
            size_bytes: 8,
        });

        fields.append(ABIField {
            name: "revocable",
            field_type: "bool",
            size_bytes: 1,
        });

        fields.append(ABIField {
            name: "ref_attestation",
            field_type: "felt252",
            size_bytes: 32,
        });

        StructABI {
            name: "AttestationData",
            fields,
            total_size: 175, // Sum of fixed-size fields
        }
    }

    fn get_field_count() -> u32 {
        8
    }

    fn serialize_to_array(self: AttestationData) -> Array<felt252> {
        let mut serialized = array![];
        self.serialize(ref serialized);
        serialized
    }
}

/// Utility functions for working with ABI information
pub mod abi_utils {
    use super::{StructABI, ABIField};

    /// Convert ABI to JSON-like string representation
    pub fn abi_to_string(abi: StructABI) -> ByteArray {
        let mut result = format!("{{\"name\":\"{}\",\"fields\":[", abi.name);

        let mut i = 0;
        loop {
            if i >= abi.fields.len() {
                break;
            }

            let field = abi.fields.at(i);
            if i > 0 {
                result.append(@",");
            }

            result.append(@format!("{{\"name\":\"{}\",\"type\":\"{}\",\"size\":{}}}",
                field.name, field.field_type, field.size_bytes));

            i += 1;
        };

        result.append(@format!("],\"total_size\":{}}}}", abi.total_size));
        result
    }

    /// Get field by name from ABI
    pub fn get_field_by_name(abi: StructABI, field_name: ByteArray) -> Option<ABIField> {
        let mut i = 0;
        loop {
            if i >= abi.fields.len() {
                break None;
            }

            let field = abi.fields.at(i);
            if field.name == field_name {
                break Option::Some(field.clone());
            }

            i += 1;
        }
    }
}

/// Example usage functions
pub mod examples {
    use super::{AttestationData, ABIProvider, abi_utils};
    use starknet::ContractAddress;

    /// Create a sample attestation
    pub fn create_sample_attestation() -> AttestationData {
        AttestationData {
            attester: starknet::contract_address_const::<0x1234>(),
            subject: starknet::contract_address_const::<0x5678>(),
            schema_id: 'identity_verification',
            data: "verified_identity_hash_abc123",
            timestamp: 1703980800, // 2023-12-31 00:00:00 UTC
            expiration: 0, // No expiration
            revocable: true,
            ref_attestation: 0,
        }
    }

    /// Demonstrate ABI extraction
    pub fn demonstrate_abi_extraction() -> ByteArray {
        let abi = AttestationDataABIProvider::get_abi();
        abi_utils::abi_to_string(abi)
    }

    /// Serialize attestation to felt252 array
    pub fn serialize_attestation(attestation: AttestationData) -> Array<felt252> {
        AttestationDataABIProvider::serialize_to_array(attestation)
    }
}

/// Derive-like utilities for automatic ABI generation
pub mod derive_utils {
    use super::*;
    use derive::*;

    /// Create ABI provider using derive-like syntax
    ///
    /// Usage:
    /// ```cairo
    /// let abi_provider = derive_attestation::<MyStruct>("MyStruct");
    /// let abi = abi_provider.get_abi();
    /// ```
    pub fn derive_attestation<T, +Serde<T>>(struct_name: ByteArray) -> impl ABIProvider<T> {
        derive::derive_standard_attestation::<T>()
    }

    /// Create custom ABI provider with builder pattern
    pub fn derive_custom<T, +Serde<T>>(struct_name: ByteArray) -> derive::DeriveBuilder {
        derive::derive::<T>(struct_name)
    }
}

#[cfg(test)]
mod tests {
    use super::{AttestationData, ABIProvider, examples, abi_utils, derive_utils};

    #[test]
    fn test_abi_generation() {
        let abi = AttestationDataABIProvider::get_abi();
        assert(abi.name == "AttestationData", 'Wrong struct name');
        assert(abi.fields.len() == 8, 'Wrong field count');
        assert(AttestationDataABIProvider::get_field_count() == 8, 'Wrong field count method');
    }

    #[test]
    fn test_serialization() {
        let attestation = examples::create_sample_attestation();
        let serialized = examples::serialize_attestation(attestation);
        assert(serialized.len() > 0, 'Serialization failed');
    }

    #[test]
    fn test_abi_string_conversion() {
        let abi_string = examples::demonstrate_abi_extraction();
        assert(abi_string.len() > 0, 'ABI string generation failed');
    }

    #[test]
    fn test_field_lookup() {
        let abi = AttestationDataABIProvider::get_abi();
        let field = abi_utils::get_field_by_name(abi, "attester");
        assert(field.is_some(), 'Field lookup failed');

        let field_info = field.unwrap();
        assert(field_info.field_type == "ContractAddress", 'Wrong field type');
    }

    #[test]
    fn test_derive_utilities() {
        let abi_provider = derive_utils::derive_attestation::<AttestationData>("AttestationData");
        let abi = abi_provider.get_abi();
        assert(abi.name == "AttestationData", 'Derive failed');
        assert(abi.fields.len() == 8, 'Wrong derived field count');
    }

    #[test]
    fn test_custom_derive() {
        let abi_provider = derive_utils::derive_custom::<AttestationData>("CustomAttestation")
            .contract_address("issuer")
            .felt252("schema")
            .u64("timestamp")
            .build();

        let abi = abi_provider.get_abi();
        assert(abi.name == "CustomAttestation", 'Custom derive failed');
        assert(abi.fields.len() == 3, 'Wrong custom field count');
    }
}
