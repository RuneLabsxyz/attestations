use starknet::ContractAddress;
use super::types::AttestationSchema;

/// Core attestation interface that all attestation contracts must implement
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
