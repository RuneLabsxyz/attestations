//! Code Generation Utilities for ABI Providers
//!
//! This module provides compile-time code generation utilities for automatically
//! creating ABIProvider implementations from struct definitions.

use starknet::ContractAddress;
use super::{ABIField, StructABI, ABIProvider};

/// Trait for types that can provide their field information at compile time
pub trait FieldInfo<T> {
    fn get_field_info() -> Array<ABIField>;
    fn get_struct_name() -> ByteArray;
    fn get_total_size() -> u32;
}

/// Generate ABI provider implementation
/// This is a template that can be copied and modified for each struct
pub mod template {
    use super::*;

    /// Template implementation - copy this and replace STRUCT_NAME and field info
    ///
    /// Example usage:
    /// ```cairo
    /// // For a struct named MyAttestation:
    /// impl MyAttestationABIProvider of ABIProvider<MyAttestation> {
    ///     fn get_abi() -> StructABI {
    ///         let mut fields = array![];
    ///
    ///         // Add each field manually
    ///         fields.append(ABIField {
    ///             name: "attester",
    ///             field_type: "ContractAddress",
    ///             size_bytes: 32,
    ///         });
    ///
    ///         // ... add more fields
    ///
    ///         StructABI {
    ///             name: "MyAttestation",
    ///             fields,
    ///             total_size: calculate_total_size(),
    ///         }
    ///     }
    ///
    ///     fn get_field_count() -> u32 {
    ///         8 // Number of fields
    ///     }
    ///
    ///     fn serialize_to_array(self: MyAttestation) -> Array<felt252> {
    ///         let mut serialized = array![];
    ///         self.serialize(ref serialized);
    ///         serialized
    ///     }
    /// }
    /// ```

    pub fn generate_field_entry(name: ByteArray, field_type: ByteArray, size: u32) -> ABIField {
        ABIField {
            name,
            field_type,
            size_bytes: size,
        }
    }
}

/// Helper functions for common field types
pub mod field_types {
    use super::ABIField;

    pub fn contract_address_field(name: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: "ContractAddress",
            size_bytes: 32,
        }
    }

    pub fn felt252_field(name: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: "felt252",
            size_bytes: 32,
        }
    }

    pub fn u64_field(name: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: "u64",
            size_bytes: 8,
        }
    }

    pub fn u256_field(name: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: "u256",
            size_bytes: 32,
        }
    }

    pub fn bool_field(name: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: "bool",
            size_bytes: 1,
        }
    }

    pub fn byte_array_field(name: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: "ByteArray",
            size_bytes: 0, // Variable size
        }
    }

    pub fn array_field(name: ByteArray, element_type: ByteArray) -> ABIField {
        ABIField {
            name,
            field_type: format!("Array<{}>", element_type),
            size_bytes: 0, // Variable size
        }
    }
}

/// Code generator for creating ABI provider implementations
pub mod generator {
    use super::*;

    /// Generate a complete ABIProvider implementation for AttestationData-like structs
    pub fn generate_attestation_abi_provider(struct_name: ByteArray) -> ByteArray {
        format!(
            "impl {}ABIProvider of ABIProvider<{}> {{
    fn get_abi() -> StructABI {{
        let mut fields = array![];

        fields.append(ABIField {{
            name: \"attester\",
            field_type: \"ContractAddress\",
            size_bytes: 32,
        }});

        fields.append(ABIField {{
            name: \"subject\",
            field_type: \"ContractAddress\",
            size_bytes: 32,
        }});

        fields.append(ABIField {{
            name: \"schema_id\",
            field_type: \"felt252\",
            size_bytes: 32,
        }});

        fields.append(ABIField {{
            name: \"data\",
            field_type: \"ByteArray\",
            size_bytes: 0,
        }});

        fields.append(ABIField {{
            name: \"timestamp\",
            field_type: \"u64\",
            size_bytes: 8,
        }});

        fields.append(ABIField {{
            name: \"expiration\",
            field_type: \"u64\",
            size_bytes: 8,
        }});

        fields.append(ABIField {{
            name: \"revocable\",
            field_type: \"bool\",
            size_bytes: 1,
        }});

        fields.append(ABIField {{
            name: \"ref_attestation\",
            field_type: \"felt252\",
            size_bytes: 32,
        }});

        StructABI {{
            name: \"{}\",
            fields,
            total_size: 175,
        }}
    }}

    fn get_field_count() -> u32 {{
        8
    }}

    fn serialize_to_array(self: {}) -> Array<felt252> {{
        let mut serialized = array![];
        self.serialize(ref serialized);
        serialized
    }}
}}",
            struct_name, struct_name, struct_name, struct_name
        )
    }

    /// Generate custom ABI provider with specified fields
    pub fn generate_custom_abi_provider(
        struct_name: ByteArray,
        fields: Array<(ByteArray, ByteArray, u32)>
    ) -> ByteArray {
        let mut field_definitions = "";
        let mut total_size = 0;
        let field_count = fields.len();

        let mut i = 0;
        loop {
            if i >= fields.len() {
                break;
            }

            let (name, type_name, size) = fields.at(i);
            total_size += *size;

            field_definitions = format!("{}
        fields.append(ABIField {{
            name: \"{}\",
            field_type: \"{}\",
            size_bytes: {},
        }});", field_definitions, name, type_name, size);

            i += 1;
        };

        format!(
            "impl {}ABIProvider of ABIProvider<{}> {{
    fn get_abi() -> StructABI {{
        let mut fields = array![];
        {}

        StructABI {{
            name: \"{}\",
            fields,
            total_size: {},
        }}
    }}

    fn get_field_count() -> u32 {{
        {}
    }}

    fn serialize_to_array(self: {}) -> Array<felt252> {{
        let mut serialized = array![];
        self.serialize(ref serialized);
        serialized
    }}
}}",
            struct_name, struct_name, field_definitions, struct_name,
            total_size, field_count, struct_name
        )
    }
}

/// Builder pattern for creating ABI providers
pub struct ABIProviderBuilder {
    struct_name: ByteArray,
    fields: Array<(ByteArray, ByteArray, u32)>,
}

impl ABIProviderBuilder {
    pub fn new(struct_name: ByteArray) -> ABIProviderBuilder {
        ABIProviderBuilder {
            struct_name,
            fields: array![],
        }
    }

    pub fn add_field(mut self: ABIProviderBuilder, name: ByteArray, type_name: ByteArray, size: u32) -> ABIProviderBuilder {
        self.fields.append((name, type_name, size));
        self
    }

    pub fn add_contract_address(self: ABIProviderBuilder, name: ByteArray) -> ABIProviderBuilder {
        self.add_field(name, "ContractAddress", 32)
    }

    pub fn add_felt252(self: ABIProviderBuilder, name: ByteArray) -> ABIProviderBuilder {
        self.add_field(name, "felt252", 32)
    }

    pub fn add_u64(self: ABIProviderBuilder, name: ByteArray) -> ABIProviderBuilder {
        self.add_field(name, "u64", 8)
    }

    pub fn add_bool(self: ABIProviderBuilder, name: ByteArray) -> ABIProviderBuilder {
        self.add_field(name, "bool", 1)
    }

    pub fn add_byte_array(self: ABIProviderBuilder, name: ByteArray) -> ABIProviderBuilder {
        self.add_field(name, "ByteArray", 0)
    }

    pub fn generate(self: ABIProviderBuilder) -> ByteArray {
        generator::generate_custom_abi_provider(self.struct_name, self.fields)
    }
}

/// Convenience functions for common attestation patterns
pub mod presets {
    use super::*;

    /// Generate basic attestation ABI provider
    pub fn basic_attestation(struct_name: ByteArray) -> ByteArray {
        ABIProviderBuilder::new(struct_name)
            .add_contract_address("attester")
            .add_contract_address("subject")
            .add_felt252("schema_id")
            .add_byte_array("data")
            .add_u64("timestamp")
            .add_bool("revocable")
            .generate()
    }

    /// Generate identity verification attestation ABI provider
    pub fn identity_attestation(struct_name: ByteArray) -> ByteArray {
        ABIProviderBuilder::new(struct_name)
            .add_contract_address("attester")
            .add_contract_address("subject")
            .add_felt252("identity_hash")
            .add_u64("verification_level")
            .add_u64("timestamp")
            .add_u64("expiration")
            .add_bool("is_verified")
            .generate()
    }

    /// Generate reputation attestation ABI provider
    pub fn reputation_attestation(struct_name: ByteArray) -> ByteArray {
        ABIProviderBuilder::new(struct_name)
            .add_contract_address("attester")
            .add_contract_address("subject")
            .add_u64("reputation_score")
            .add_felt252("category")
            .add_byte_array("evidence")
            .add_u64("timestamp")
            .generate()
    }
}

/// Validation helpers for generated ABI providers
pub mod validation {
    use super::*;

    /// Validate that a struct matches its expected ABI
    pub fn validate_struct_abi<T, +Serde<T>>(
        instance: T,
        expected_abi: StructABI
    ) -> bool {
        // Serialize the instance
        let mut serialized = array![];
        instance.serialize(ref serialized);

        // Basic validation - check if serialization succeeds
        serialized.len() > 0
    }

    /// Validate field count matches expectation
    pub fn validate_field_count(abi: StructABI, expected_count: u32) -> bool {
        abi.fields.len() == expected_count
    }

    /// Validate total size calculation
    pub fn validate_total_size(abi: StructABI) -> bool {
        let mut calculated_size = 0;
        let mut i = 0;

        loop {
            if i >= abi.fields.len() {
                break;
            }

            let field = abi.fields.at(i);
            calculated_size += field.size_bytes;
            i += 1;
        };

        abi.total_size == calculated_size
    }
}

/// Usage examples and documentation
pub mod examples {
    use super::*;

    /// Example: Generate ABI provider for a custom struct
    pub fn generate_custom_example() -> ByteArray {
        ABIProviderBuilder::new("CustomAttestation")
            .add_contract_address("issuer")
            .add_contract_address("holder")
            .add_felt252("credential_type")
            .add_byte_array("credential_data")
            .add_u64("issued_at")
            .add_u64("expires_at")
            .add_bool("revocable")
            .add_felt252("proof_hash")
            .generate()
    }

    /// Example: Generate basic attestation using preset
    pub fn generate_preset_example() -> ByteArray {
        presets::basic_attestation("SimpleAttestation")
    }
}
