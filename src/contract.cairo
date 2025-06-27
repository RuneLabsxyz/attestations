//! Attestation ABI Contract
//!
//! This contract provides an interface for working with attestation data structures
//! and their ABI information on-chain.

use starknet::ContractAddress;
use super::{AttestationData, StructABI, ABIProvider, AttestationDataABIProvider, abi_utils};

// Define the contract interface
#[starknet::interface]
pub trait IAttestationABI<TContractState> {
    fn get_attestation_abi(self: @TContractState) -> StructABI;
    fn get_abi_as_string(self: @TContractState) -> ByteArray;
    fn create_and_serialize_attestation(
        ref self: TContractState,
        subject: ContractAddress,
        schema_id: felt252,
        data: ByteArray,
        expiration: u64,
        revocable: bool,
        ref_attestation: felt252
    ) -> Array<felt252>;
    fn get_field_info(self: @TContractState, field_name: ByteArray) -> ByteArray;
    fn validate_attestation_format(self: @TContractState, serialized_data: Array<felt252>) -> bool;
}

// Define the contract module
#[starknet::contract]
pub mod AttestationABIContract {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use super::{AttestationData, StructABI, ABIProvider, AttestationDataABIProvider, abi_utils};

    // Define storage variables
    #[storage]
    pub struct Storage {
        attestation_count: u64,
        stored_attestations: Map<u64, AttestationData>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AttestationCreated: AttestationCreated,
        ABIRequested: ABIRequested,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttestationCreated {
        id: u64,
        attester: ContractAddress,
        subject: ContractAddress,
        schema_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ABIRequested {
        requester: ContractAddress,
        timestamp: u64,
    }

    // Implement the contract interface
    #[abi(embed_v0)]
    pub impl AttestationABIImpl of super::IAttestationABI<ContractState> {
        /// Get the complete ABI structure for AttestationData
        fn get_attestation_abi(self: @ContractState) -> StructABI {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            self.emit(Event::ABIRequested(ABIRequested { requester: caller, timestamp }));

            AttestationDataABIProvider::get_abi()
        }

        /// Get the ABI as a JSON-like string representation
        fn get_abi_as_string(self: @ContractState) -> ByteArray {
            let abi = AttestationDataABIProvider::get_abi();
            abi_utils::abi_to_string(abi)
        }

        /// Create a new attestation and return its serialized form
        fn create_and_serialize_attestation(
            ref self: ContractState,
            subject: ContractAddress,
            schema_id: felt252,
            data: ByteArray,
            expiration: u64,
            revocable: bool,
            ref_attestation: felt252
        ) -> Array<felt252> {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let current_count = self.attestation_count.read();

            let attestation = AttestationData {
                attester: caller,
                subject,
                schema_id,
                data,
                timestamp,
                expiration,
                revocable,
                ref_attestation,
            };

            // Store the attestation
            self.stored_attestations.entry(current_count).write(attestation.clone());
            self.attestation_count.write(current_count + 1);

            // Emit event
            self.emit(Event::AttestationCreated(AttestationCreated {
                id: current_count,
                attester: caller,
                subject,
                schema_id,
            }));

            // Return serialized attestation
            AttestationDataABIProvider::serialize_to_array(attestation)
        }

        /// Get information about a specific field in the ABI
        fn get_field_info(self: @ContractState, field_name: ByteArray) -> ByteArray {
            let abi = AttestationDataABIProvider::get_abi();
            let field_option = abi_utils::get_field_by_name(abi, field_name);

            match field_option {
                Option::Some(field) => {
                    format!("{{\"name\":\"{}\",\"type\":\"{}\",\"size\":{}}}",
                        field.name, field.field_type, field.size_bytes)
                },
                Option::None => "Field not found"
            }
        }

        /// Validate if the provided serialized data matches the expected attestation format
        fn validate_attestation_format(self: @ContractState, serialized_data: Array<felt252>) -> bool {
            // Basic validation - check if we can deserialize it back to AttestationData
            let mut span = serialized_data.span();
            let result: Result<AttestationData, Array<felt252>> = Serde::deserialize(ref span);
            result.is_ok()
        }
    }

    // Private helper functions
    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn get_attestation_by_id(self: @ContractState, id: u64) -> AttestationData {
            self.stored_attestations.entry(id).read()
        }

        fn get_total_attestations(self: @ContractState) -> u64 {
            self.attestation_count.read()
        }
    }
}
