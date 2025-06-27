//! Comprehensive Example: Using Derive-like ABI Generation
//!
//! This example demonstrates how to use the derive-like utilities to automatically
//! generate ABIProvider implementations for custom attestation structs.

use starknet::ContractAddress;
use attestations::{ABIProvider, StructABI, ABIField, derive_utils};

/// Example 1: Basic custom attestation struct
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct EducationAttestation {
    pub issuer: ContractAddress,        // Educational institution
    pub student: ContractAddress,       // Student address
    pub degree_type: felt252,          // Bachelor, Master, PhD, etc.
    pub field_of_study: felt252,       // Computer Science, Mathematics, etc.
    pub graduation_year: u64,          // Year of graduation
    pub gpa: u64,                      // GPA * 100 (e.g., 350 = 3.50)
    pub is_verified: bool,             // Verification status
    pub credential_hash: felt252,      // Hash of the credential document
}

/// Example 2: Identity verification attestation
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct IdentityAttestation {
    pub verifier: ContractAddress,      // KYC provider
    pub subject: ContractAddress,       // Person being verified
    pub identity_hash: felt252,        // Hash of identity document
    pub verification_level: u64,       // 1=basic, 2=enhanced, 3=premium
    pub document_type: felt252,        // passport, driver_license, etc.
    pub issue_date: u64,               // When document was issued
    pub expiry_date: u64,              // When document expires
    pub country_code: felt252,         // ISO country code
    pub is_active: bool,               // Current verification status
}

/// Example 3: Simple reputation attestation
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct ReputationAttestation {
    pub rater: ContractAddress,
    pub ratee: ContractAddress,
    pub category: felt252,             // service_provider, buyer, seller, etc.
    pub score: u64,                    // 1-100 rating score
    pub transaction_hash: felt252,     // Related transaction
    pub timestamp: u64,
}

/// Main function demonstrating all derive patterns
fn main() {
    println!("=== Cairo Derive-like ABI Generation Examples ===\n");

    // Example 1: Using derive_attestation for standard pattern
    demonstrate_standard_derive();

    // Example 2: Using custom derive builder
    demonstrate_custom_derive();

    // Example 3: Using specialized derives
    demonstrate_specialized_derives();

    // Example 4: Working with generated ABIs
    demonstrate_abi_usage();

    println!("\n=== All examples completed successfully! ===");
}

/// Demonstrate standard attestation derive
fn demonstrate_standard_derive() {
    println!("1. Standard Attestation Derive:");

    // This simulates #[derive(Attestation)] behavior
    let abi_provider = derive_utils::derive_attestation::<EducationAttestation>("EducationAttestation");
    let abi = abi_provider.get_abi();

    println!("   ✓ Generated ABI for standard attestation pattern");
    println!("   ✓ Struct: {}", abi.name);
    println!("   ✓ Fields: {}", abi.fields.len());

    // Create and serialize an instance
    let education = EducationAttestation {
        issuer: starknet::contract_address_const::<0x111>(),
        student: starknet::contract_address_const::<0x222>(),
        degree_type: 'bachelor',
        field_of_study: 'computer_science',
        graduation_year: 2023,
        gpa: 385, // 3.85 GPA
        is_verified: true,
        credential_hash: 'hash_of_diploma_document',
    };

    let serialized = abi_provider.serialize_to_array(education);
    println!("   ✓ Serialized to {} felt252 elements", serialized.len());
}

/// Demonstrate custom derive builder
fn demonstrate_custom_derive() {
    println!("\n2. Custom Derive Builder:");

    // Create custom ABI provider using builder pattern
    let abi_provider = derive_utils::derive_custom::<EducationAttestation>("EducationAttestation")
        .contract_address("issuer")
        .contract_address("student")
        .felt252("degree_type")
        .felt252("field_of_study")
        .u64("graduation_year")
        .u64("gpa")
        .bool("is_verified")
        .felt252("credential_hash")
        .build();

    let abi = abi_provider.get_abi();
    println!("   ✓ Built custom ABI with {} fields", abi.fields.len());
    println!("   ✓ Total size: {} bytes", abi.total_size);

    // Show field details
    println!("   ✓ Field breakdown:");
    let mut i = 0;
    loop {
        if i >= abi.fields.len() {
            break;
        }
        let field = abi.fields.at(i);
        println!("     - {}: {} ({} bytes)", field.name, field.field_type, field.size_bytes);
        i += 1;
    };
}

/// Demonstrate specialized derive functions
fn demonstrate_specialized_derives() {
    println!("\n3. Specialized Derive Functions:");

    // Identity attestation derive
    let identity_provider = derive_utils::derive_custom::<IdentityAttestation>("IdentityAttestation")
        .contract_address("verifier")
        .contract_address("subject")
        .felt252("identity_hash")
        .u64("verification_level")
        .felt252("document_type")
        .u64("issue_date")
        .u64("expiry_date")
        .felt252("country_code")
        .bool("is_active")
        .build();

    let identity_abi = identity_provider.get_abi();
    println!("   ✓ Identity ABI: {} fields, {} bytes",
             identity_abi.fields.len(), identity_abi.total_size);

    // Reputation attestation derive
    let reputation_provider = derive_utils::derive_custom::<ReputationAttestation>("ReputationAttestation")
        .contract_address("rater")
        .contract_address("ratee")
        .felt252("category")
        .u64("score")
        .felt252("transaction_hash")
        .u64("timestamp")
        .build();

    let reputation_abi = reputation_provider.get_abi();
    println!("   ✓ Reputation ABI: {} fields, {} bytes",
             reputation_abi.fields.len(), reputation_abi.total_size);
}

/// Demonstrate working with generated ABIs
fn demonstrate_abi_usage() {
    println!("\n4. Working with Generated ABIs:");

    // Create instances of different attestation types
    let education = create_sample_education();
    let identity = create_sample_identity();
    let reputation = create_sample_reputation();

    // Generate ABIs and process them
    process_attestation("Education", education);
    process_attestation("Identity", identity);
    process_attestation("Reputation", reputation);

    println!("   ✓ Processed all attestation types successfully");
}

/// Helper function to create sample education attestation
fn create_sample_education() -> EducationAttestation {
    EducationAttestation {
        issuer: starknet::contract_address_const::<0x1000>(),
        student: starknet::contract_address_const::<0x2000>(),
        degree_type: 'master',
        field_of_study: 'blockchain_engineering',
        graduation_year: 2024,
        gpa: 390, // 3.90 GPA
        is_verified: true,
        credential_hash: 'sample_credential_hash_123',
    }
}

/// Helper function to create sample identity attestation
fn create_sample_identity() -> IdentityAttestation {
    IdentityAttestation {
        verifier: starknet::contract_address_const::<0x3000>(),
        subject: starknet::contract_address_const::<0x4000>(),
        identity_hash: 'identity_document_hash_456',
        verification_level: 2, // Enhanced verification
        document_type: 'passport',
        issue_date: 1640995200, // 2022-01-01
        expiry_date: 1956528000, // 2032-01-01
        country_code: 'US',
        is_active: true,
    }
}

/// Helper function to create sample reputation attestation
fn create_sample_reputation() -> ReputationAttestation {
    ReputationAttestation {
        rater: starknet::contract_address_const::<0x5000>(),
        ratee: starknet::contract_address_const::<0x6000>(),
        category: 'service_provider',
        score: 92, // 92/100 rating
        transaction_hash: 'transaction_hash_789',
        timestamp: 1703980800, // 2023-12-31
    }
}

/// Generic function to process any attestation type
fn process_attestation<T, +Serde<T>>(attestation_type: ByteArray, instance: T) {
    // This demonstrates how you could work with attestations generically
    let mut serialized = array![];
    instance.serialize(ref serialized);

    println!("   ✓ {} attestation: {} serialized elements",
             attestation_type, serialized.len());

    // Could add validation, storage, etc. here
}

/// Advanced usage example: Batch processing with derive
pub mod advanced_examples {
    use super::*;

    /// Process multiple attestations of the same type
    pub fn batch_process_education() {
        let attestations = array![
            create_sample_education(),
            EducationAttestation {
                issuer: starknet::contract_address_const::<0x7000>(),
                student: starknet::contract_address_const::<0x8000>(),
                degree_type: 'phd',
                field_of_study: 'cryptography',
                graduation_year: 2025,
                gpa: 395,
                is_verified: true,
                credential_hash: 'phd_credential_hash',
            },
        ];

        // Process each attestation
        let mut i = 0;
        loop {
            if i >= attestations.len() {
                break;
            }

            let attestation = attestations.at(i);
            process_attestation("Education", attestation.clone());
            i += 1;
        };
    }

    /// Demonstrate ABI comparison between types
    pub fn compare_abis() {
        let edu_provider = derive_utils::derive_custom::<EducationAttestation>("EducationAttestation")
            .contract_address("issuer")
            .contract_address("student")
            .felt252("degree_type")
            .felt252("field_of_study")
            .u64("graduation_year")
            .u64("gpa")
            .bool("is_verified")
            .felt252("credential_hash")
            .build();

        let rep_provider = derive_utils::derive_custom::<ReputationAttestation>("ReputationAttestation")
            .contract_address("rater")
            .contract_address("ratee")
            .felt252("category")
            .u64("score")
            .felt252("transaction_hash")
            .u64("timestamp")
            .build();

        let edu_abi = edu_provider.get_abi();
        let rep_abi = rep_provider.get_abi();

        println!("ABI Comparison:");
        println!("  Education: {} fields, {} bytes", edu_abi.fields.len(), edu_abi.total_size);
        println!("  Reputation: {} fields, {} bytes", rep_abi.fields.len(), rep_abi.total_size);
    }
}

/// Best practices for using derive-like ABI generation
pub mod best_practices {
    use super::*;

    /// Always validate your ABI after generation
    pub fn validate_generated_abi<T, +Serde<T>>(
        abi_provider: impl ABIProvider<T>,
        expected_field_count: u32
    ) -> bool {
        let abi = abi_provider.get_abi();

        // Basic validations
        if abi.fields.len() != expected_field_count {
            return false;
        }

        if abi.name.len() == 0 {
            return false;
        }

        // Validate each field has required information
        let mut i = 0;
        loop {
            if i >= abi.fields.len() {
                break;
            }

            let field = abi.fields.at(i);
            if field.name.len() == 0 || field.field_type.len() == 0 {
                return false;
            }

            i += 1;
        };

        true
    }

    /// Use consistent naming conventions
    pub fn demonstrate_naming_conventions() {
        // Good: Clear, descriptive names
        let _good_provider = derive_utils::derive_custom::<EducationAttestation>("EducationCredentialAttestation")
            .contract_address("educational_institution")
            .contract_address("credential_holder")
            .felt252("degree_classification")
            .felt252("academic_discipline")
            .build();

        // Avoid: Vague or abbreviated names that reduce clarity
    }
}
