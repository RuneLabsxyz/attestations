//! Cairo Macros for Automatic ABI Generation
//!
//! This module provides macros to automatically generate ABIProvider implementations
//! for Cairo structs, making it easy to work with attestation data structures.

/// Macro to generate ABIProvider implementation for a struct
///
/// Usage:
/// ```cairo
/// generate_abi_provider!(
///     MyStruct,
///     [
///         (field1, "ContractAddress", 32),
///         (field2, "felt252", 32),
///         (field3, "u64", 8),
///     ]
/// );
/// ```
#[macro_export]
macro_rules! generate_abi_provider {
    ($struct_name:ident, [$(($field_name:ident, $field_type:expr, $field_size:expr)),* $(,)?]) => {
        paste::paste! {
            impl [<$struct_name ABIProvider>] of ABIProvider<$struct_name> {
                fn get_abi() -> StructABI {
                    let mut fields = array![];

                    $(
                        fields.append(ABIField {
                            name: stringify!($field_name),
                            field_type: $field_type,
                            size_bytes: $field_size,
                        });
                    )*

                    StructABI {
                        name: stringify!($struct_name),
                        fields,
                        total_size: 0 $(+ $field_size)*,
                    }
                }

                fn get_field_count() -> u32 {
                    let mut count = 0;
                    $(
                        count += 1;
                        let _ = stringify!($field_name); // Use the field name to avoid unused warning
                    )*
                    count
                }

                fn serialize_to_array(self: $struct_name) -> Array<felt252> {
                    let mut serialized = array![];
                    self.serialize(ref serialized);
                    serialized
                }
            }
        }
    };
}

/// Simplified macro for common attestation fields
///
/// Usage:
/// ```cairo
/// generate_attestation_abi!(MyAttestation);
/// ```
#[macro_export]
macro_rules! generate_attestation_abi {
    ($struct_name:ident) => {
        generate_abi_provider!(
            $struct_name,
            [
                (attester, "ContractAddress", 32),
                (subject, "ContractAddress", 32),
                (schema_id, "felt252", 32),
                (data, "ByteArray", 0),
                (timestamp, "u64", 8),
                (expiration, "u64", 8),
                (revocable, "bool", 1),
                (ref_attestation, "felt252", 32),
            ]
        );
    };
}

/// Macro to generate ABI for custom struct with automatic type detection
///
/// Usage:
/// ```cairo
/// define_attestation_struct!(
///     CustomAttestation,
///     {
///         attester: ContractAddress,
///         subject: ContractAddress,
///         schema_id: felt252,
///         custom_data: ByteArray,
///         amount: u256,
///         is_valid: bool,
///     }
/// );
/// ```
#[macro_export]
macro_rules! define_attestation_struct {
    ($struct_name:ident, { $($field_name:ident: $field_type:ty),* $(,)? }) => {
        #[derive(Drop, Serde, Clone, PartialEq)]
        pub struct $struct_name {
            $(
                pub $field_name: $field_type,
            )*
        }

        generate_abi_provider!(
            $struct_name,
            [
                $(
                    ($field_name, get_type_name!($field_type), get_type_size!($field_type)),
                )*
            ]
        );
    };
}

/// Helper macro to get type name as string
#[macro_export]
macro_rules! get_type_name {
    (ContractAddress) => { "ContractAddress" };
    (felt252) => { "felt252" };
    (u8) => { "u8" };
    (u16) => { "u16" };
    (u32) => { "u32" };
    (u64) => { "u64" };
    (u128) => { "u128" };
    (u256) => { "u256" };
    (bool) => { "bool" };
    (ByteArray) => { "ByteArray" };
    ($other:ty) => { stringify!($other) };
}

/// Helper macro to get type size in bytes
#[macro_export]
macro_rules! get_type_size {
    (ContractAddress) => { 32 };
    (felt252) => { 32 };
    (u8) => { 1 };
    (u16) => { 2 };
    (u32) => { 4 };
    (u64) => { 8 };
    (u128) => { 16 };
    (u256) => { 32 };
    (bool) => { 1 };
    (ByteArray) => { 0 }; // Variable size
    ($other:ty) => { 0 }; // Unknown types default to 0
}

/// Macro to quickly create a sample attestation with default values
///
/// Usage:
/// ```cairo
/// let attestation = create_sample_attestation!(
///     MyAttestation,
///     attester: contract_address_const::<0x123>(),
///     subject: contract_address_const::<0x456>(),
///     schema_id: 'test_schema',
///     data: "test_data"
/// );
/// ```
#[macro_export]
macro_rules! create_sample_attestation {
    ($struct_name:ident, $($field:ident: $value:expr),* $(,)?) => {
        $struct_name {
            $(
                $field: $value,
            )*
            // Provide defaults for common fields not specified
            ..Default::default()
        }
    };
}

/// Macro to batch process attestations with the same ABI
///
/// Usage:
/// ```cairo
/// let results = batch_process_attestations!(
///     [attestation1, attestation2, attestation3],
///     |att| {
///         let serialized = MyAttestationABIProvider::serialize_to_array(att);
///         // Process serialized data
///         serialized.len()
///     }
/// );
/// ```
#[macro_export]
macro_rules! batch_process_attestations {
    ([$($attestation:expr),* $(,)?], $processor:expr) => {
        {
            let mut results = array![];
            $(
                let result = $processor($attestation);
                results.append(result);
            )*
            results
        }
    };
}

/// Macro to validate attestation schema at compile time
///
/// Usage:
/// ```cairo
/// validate_attestation_schema!(
///     MyAttestation,
///     required_fields: [attester, subject, schema_id],
///     optional_fields: [data, timestamp]
/// );
/// ```
#[macro_export]
macro_rules! validate_attestation_schema {
    (
        $struct_name:ident,
        required_fields: [$($req_field:ident),* $(,)?],
        optional_fields: [$($opt_field:ident),* $(,)?]
    ) => {
        // This would be expanded to validation logic
        // For now, it's a compile-time check that fields exist
        const _: fn() = || {
            $(
                let _: fn($struct_name) -> _ = |s| s.$req_field;
            )*
            $(
                let _: fn($struct_name) -> _ = |s| s.$opt_field;
            )*
        };
    };
}

/// Convenience macro to implement all necessary traits for an attestation struct
///
/// Usage:
/// ```cairo
/// impl_attestation_traits!(MyAttestation);
/// ```
#[macro_export]
macro_rules! impl_attestation_traits {
    ($struct_name:ident) => {
        // Implement Default trait with sensible defaults
        impl Default<$struct_name> of Default<$struct_name> {
            fn default() -> $struct_name {
                $struct_name {
                    attester: contract_address_const::<0x0>(),
                    subject: contract_address_const::<0x0>(),
                    schema_id: 0,
                    data: "",
                    timestamp: 0,
                    expiration: 0,
                    revocable: true,
                    ref_attestation: 0,
                }
            }
        }

        // Generate the ABI provider
        generate_attestation_abi!($struct_name);

        // Implement display trait for debugging
        impl Display<$struct_name> of Display<$struct_name> {
            fn fmt(self: @$struct_name, ref f: Formatter) -> Result<(), Error> {
                write!(f, "{}(attester: {}, subject: {}, schema: {})",
                       stringify!($struct_name),
                       *self.attester,
                       *self.subject,
                       *self.schema_id)
            }
        }
    };
}

/// Macro for creating ABI-aware attestation with validation
///
/// Usage:
/// ```cairo
/// let attestation = create_validated_attestation!(
///     MyAttestation,
///     attester: caller_address,
///     subject: target_address,
///     schema_id: 'identity_verification',
///     data: verification_data,
///     validate: |att| att.attester != att.subject
/// );
/// ```
#[macro_export]
macro_rules! create_validated_attestation {
    (
        $struct_name:ident,
        $($field:ident: $value:expr),*,
        validate: $validator:expr
    ) => {
        {
            let attestation = $struct_name {
                $(
                    $field: $value,
                )*
                ..Default::default()
            };

            // Run validation
            assert!($validator(&attestation), "Attestation validation failed");

            attestation
        }
    };
}

// Re-export commonly used macros
pub use generate_abi_provider;
pub use generate_attestation_abi;
pub use define_attestation_struct;
pub use impl_attestation_traits;
pub use create_sample_attestation;
pub use batch_process_attestations;
