//! Main example script demonstrating ABI extraction for attestations
//!
//! This script shows how to work with the attestation ABI utilities
//! and extract struct information for serialization purposes.

use attestations::{
    AttestationData, ABIProvider, AttestationDataABIProvider,
    abi_utils, examples
};
use starknet::ContractAddress;

/// Main entry point for the example
fn main() {
    println!("=== Attestation ABI Extraction Example ===\n");

    // 1. Create a sample attestation
    println!("1. Creating sample attestation...");
    let sample_attestation = examples::create_sample_attestation();
    println!("   ✓ Sample attestation created");

    // 2. Extract and display ABI information
    println!("\n2. Extracting ABI information...");
    let abi = AttestationDataABIProvider::get_abi();
    println!("   ✓ Struct name: {}", abi.name);
    println!("   ✓ Field count: {}", abi.fields.len());
    println!("   ✓ Total size: {} bytes", abi.total_size);

    // 3. Display all fields
    println!("\n3. Field details:");
    let mut i = 0;
    loop {
        if i >= abi.fields.len() {
            break;
        }
        let field = abi.fields.at(i);
        println!("   - {}: {} ({} bytes)",
            field.name, field.field_type, field.size_bytes);
        i += 1;
    };

    // 4. Convert ABI to string format
    println!("\n4. ABI as JSON-like string:");
    let abi_string = examples::demonstrate_abi_extraction();
    println!("{}", abi_string);

    // 5. Serialize the attestation
    println!("\n5. Serializing attestation...");
    let serialized = examples::serialize_attestation(sample_attestation);
    println!("   ✓ Serialized to {} felt252 elements", serialized.len());

    // Display first few elements
    println!("   First few elements:");
    let mut j = 0;
    loop {
        if j >= 5 || j >= serialized.len() {
            break;
        }
        println!("   [{}]: {}", j, *serialized.at(j));
        j += 1;
    };

    // 6. Field lookup example
    println!("\n6. Field lookup examples:");
    let attester_field = abi_utils::get_field_by_name(abi.clone(), "attester");
    match attester_field {
        Option::Some(field) => {
            println!("   ✓ Found 'attester' field: {} ({})",
                field.field_type, field.size_bytes);
        },
        Option::None => println!("   ✗ Field 'attester' not found"),
    }

    let nonexistent_field = abi_utils::get_field_by_name(abi, "nonexistent");
    match nonexistent_field {
        Option::Some(_) => println!("   ✗ Unexpected field found"),
        Option::None => println!("   ✓ Correctly handled nonexistent field"),
    }

    println!("\n=== Example completed successfully! ===");
    println!("\nThis demonstrates how to:");
    println!("- Define serializable structs with the Serde trait");
    println!("- Extract ABI information programmatically");
    println!("- Convert structs to serialized format");
    println!("- Look up field information by name");
    println!("- Generate JSON-like ABI representations");
}

/// Helper function to demonstrate custom attestation creation
fn create_custom_attestation(
    attester: ContractAddress,
    subject: ContractAddress,
    schema: felt252,
    data: ByteArray
) -> AttestationData {
    AttestationData {
        attester,
        subject,
        schema_id: schema,
        data,
        timestamp: 1703980800,
        expiration: 0,
        revocable: true,
        ref_attestation: 0,
    }
}

/// Demonstrate working with multiple attestations
fn batch_processing_example() {
    println!("\n=== Batch Processing Example ===");

    let mut attestations = array![];

    // Create multiple sample attestations
    attestations.append(examples::create_sample_attestation());
    attestations.append(create_custom_attestation(
        starknet::contract_address_const::<0xAAA>(),
        starknet::contract_address_const::<0xBBB>(),
        'email_verification',
        "email_verified_example@domain.com"
    ));
    attestations.append(create_custom_attestation(
        starknet::contract_address_const::<0xCCC>(),
        starknet::contract_address_const::<0xDDD>(),
        'age_verification',
        "age_verified_over_18"
    ));

    println!("Created {} attestations for batch processing", attestations.len());

    // Process each attestation
    let mut i = 0;
    loop {
        if i >= attestations.len() {
            break;
        }

        let attestation = attestations.at(i);
        let serialized = AttestationDataABIProvider::serialize_to_array(attestation.clone());

        println!("Attestation {}: Schema '{}', {} serialized elements",
            i, attestation.schema_id, serialized.len());

        i += 1;
    };
}
