# Cairo Attestation ABI Library

A Cairo library for working with attestation data structures and extracting their ABI (Application Binary Interface) information. This project demonstrates how to create serializable structs in Cairo and programmatically access their structure information for attestation systems.

## Features

- **Serializable Attestation Struct**: A comprehensive `AttestationData` structure with all common attestation fields
- **ABI Extraction**: Programmatically extract field information, types, and sizes
- **Derive-like ABI Generation**: Automatic ABIProvider implementation generation (similar to `#[derive(Attestation)]`)
- **JSON-like ABI Representation**: Convert ABI information to string format
- **Field Lookup**: Find specific fields by name within the ABI
- **Serialization Utilities**: Convert structs to felt252 arrays for storage/transmission
- **Smart Contract Interface**: On-chain ABI access through contract calls
- **Builder Pattern**: Flexible ABI provider construction with type-safe builder

## Project Structure

```
attestations/
├── Scarb.toml              # Project configuration
├── src/
│   ├── lib.cairo          # Main library with AttestationData and ABI utilities
│   ├── contract.cairo     # Smart contract for on-chain ABI access
│   ├── derive.cairo       # Derive-like utilities for automatic ABI generation
│   ├── codegen.cairo      # Code generation utilities and templates
│   └── main.cairo         # Example usage and demonstrations
├── examples/
│   └── derive_example.cairo  # Comprehensive derive usage examples
├── crates/
│   ├── attestation-derive/   # Rust procedural macro (experimental)
│   └── cairo-attestation-plugin/  # Cairo plugin (experimental)
└── README.md
```

## AttestationData Structure

The core `AttestationData` struct includes:

```cairo
pub struct AttestationData {
    pub attester: ContractAddress,      // Who made the attestation
    pub subject: ContractAddress,       // Who/what is being attested
    pub schema_id: felt252,            // Type of attestation
    pub data: ByteArray,               // The actual attestation payload
    pub timestamp: u64,                // When it was created
    pub expiration: u64,               // When it expires (0 = never)
    pub revocable: bool,               // Can it be revoked?
    pub ref_attestation: felt252,      // Reference to another attestation
}
```

## Usage Examples

### Derive-like ABI Generation (Recommended)

The easiest way to generate ABI providers is using the derive-like utilities:

```cairo
use attestations::derive_utils;
use starknet::ContractAddress;

// Define your custom attestation struct
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct EducationAttestation {
    pub issuer: ContractAddress,
    pub student: ContractAddress,
    pub degree_type: felt252,
    pub graduation_year: u64,
    pub gpa: u64,
    pub is_verified: bool,
}

// Generate ABI provider using builder pattern
let abi_provider = derive_utils::derive_custom::<EducationAttestation>("EducationAttestation")
    .contract_address("issuer")
    .contract_address("student")
    .felt252("degree_type")
    .u64("graduation_year")
    .u64("gpa")
    .bool("is_verified")
    .build();

// Use the generated ABI provider
let abi = abi_provider.get_abi();
println!("Struct: {}", abi.name);
println!("Fields: {}", abi.fields.len());
println!("Total size: {} bytes", abi.total_size);
```

### Standard Attestation Derive

For AttestationData-like structures, use the standard derive:

```cairo
use attestations::{AttestationData, derive_utils};

// Automatically generate ABI provider for standard attestation pattern
let abi_provider = derive_utils::derive_attestation::<AttestationData>("AttestationData");
let abi = abi_provider.get_abi();
```

### Basic ABI Extraction (Manual Implementation)

For manual implementations, you can still use the traditional approach:

```cairo
use attestations::{AttestationData, ABIProvider, AttestationDataABIProvider};

// Get the complete ABI structure
let abi = AttestationDataABIProvider::get_abi();
println!("Struct: {}", abi.name);
println!("Fields: {}", abi.fields.len());
println!("Total size: {} bytes", abi.total_size);
```

### Creating and Serializing Attestations

```cairo
use attestations::{examples, derive_utils};

// Method 1: Using examples
let attestation = examples::create_sample_attestation();
let serialized = examples::serialize_attestation(attestation);
println!("Serialized to {} elements", serialized.len());

// Method 2: Using derive-generated ABI provider
let custom_attestation = EducationAttestation {
    issuer: starknet::contract_address_const::<0x123>(),
    student: starknet::contract_address_const::<0x456>(),
    degree_type: 'bachelor',
    graduation_year: 2024,
    gpa: 385, // 3.85 GPA
    is_verified: true,
};

let abi_provider = derive_utils::derive_custom::<EducationAttestation>("EducationAttestation")
    .contract_address("issuer")
    .contract_address("student")
    .felt252("degree_type")
    .u64("graduation_year")
    .u64("gpa")
    .bool("is_verified")
    .build();

let serialized = abi_provider.serialize_to_array(custom_attestation);
println!("Custom attestation serialized to {} elements", serialized.len());
```

### Field Information Lookup

```cairo
use attestations::abi_utils;

let abi = AttestationDataABIProvider::get_abi();
let field = abi_utils::get_field_by_name(abi, "attester");

match field {
    Option::Some(field_info) => {
        println!("Field type: {}", field_info.field_type);
        println!("Size: {} bytes", field_info.size_bytes);
    },
    Option::None => println!("Field not found"),
}
```

### JSON-like ABI Representation

```cairo
use attestations::{abi_utils, AttestationDataABIProvider};

let abi = AttestationDataABIProvider::get_abi();
let json_abi = abi_utils::abi_to_string(abi);
println!("{}", json_abi);
```

Output example:
```json
{
  "name": "AttestationData",
  "fields": [
    {"name": "attester", "type": "ContractAddress", "size": 32},
    {"name": "subject", "type": "ContractAddress", "size": 32},
    {"name": "schema_id", "type": "felt252", "size": 32},
    {"name": "data", "type": "ByteArray", "size": 0},
    {"name": "timestamp", "type": "u64", "size": 8},
    {"name": "expiration", "type": "u64", "size": 8},
    {"name": "revocable", "type": "bool", "size": 1},
    {"name": "ref_attestation", "type": "felt252", "size": 32}
  ],
  "total_size": 175
}
```

## Smart Contract Usage

Deploy the `AttestationABIContract` to access ABI information on-chain:

```cairo
// Get ABI structure
let abi = contract.get_attestation_abi();

// Get ABI as string
let abi_string = contract.get_abi_as_string();

// Create and serialize new attestation
let serialized = contract.create_and_serialize_attestation(
    subject_address,
    'identity_verification',
    "verified_data_payload",
    0, // no expiration
    true, // revocable
    0 // no reference
);

// Get specific field information
let field_info = contract.get_field_info("timestamp");
```

## Building and Testing

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- Cairo compiler

### Build the project

```bash
cd attestations
scarb build
```

### Run tests

```bash
scarb test
```

### Run the example

```bash
scarb cairo-run --package attestations
```

## Use Cases for Attestations

This library is designed to support various attestation scenarios:

1. **Identity Verification**: Attest to someone's identity verification status
2. **Credential Verification**: Attest to educational, professional, or other credentials
3. **Reputation Systems**: Build trust networks through attestations
4. **Compliance**: Attest to regulatory compliance or audit results
5. **Social Proof**: Attest to participation, achievements, or endorsements

## Advanced Features

### Derive-like ABI Generation Patterns

#### 1. Standard Attestation Pattern
```cairo
// For AttestationData-like structures
let abi_provider = derive_utils::derive_attestation::<MyStruct>("MyStruct");
```

#### 2. Custom Builder Pattern
```cairo
// For completely custom structures
let abi_provider = derive_utils::derive_custom::<MyStruct>("MyStruct")
    .contract_address("field1")
    .felt252("field2")
    .u64("field3")
    .bool("field4")
    .byte_array("field5")
    .build();
```

#### 3. Batch Processing
```cairo
// Process multiple attestations with same ABI
let attestations = array![attestation1, attestation2, attestation3];
let mut i = 0;
loop {
    if i >= attestations.len() { break; }
    let serialized = abi_provider.serialize_to_array(attestations.at(i).clone());
    // Process each serialized attestation
    i += 1;
};
```

### Custom Attestation Types (Manual Implementation)

For advanced use cases, you can still manually implement the `ABIProvider` trait:

```cairo
#[derive(Drop, Serde, Clone)]
pub struct CustomAttestation {
    pub custom_field: felt252,
    // ... other fields
}

impl CustomAttestationABIProvider of ABIProvider<CustomAttestation> {
    fn get_abi() -> StructABI {
        // Manual implementation
        let mut fields = array![];
        fields.append(ABIField {
            name: "custom_field",
            field_type: "felt252",
            size_bytes: 32,
        });
        
        StructABI {
            name: "CustomAttestation",
            fields,
            total_size: 32,
        }
    }
    
    fn get_field_count() -> u32 {
        1
    }
    
    fn serialize_to_array(self: CustomAttestation) -> Array<felt252> {
        let mut serialized = array![];
        self.serialize(ref serialized);
        serialized
    }
}
```

### Code Generation Templates

The library also provides code generation utilities for creating boilerplate:

```cairo
use attestations::codegen::{generator, presets};

// Generate code for basic attestation
let code = presets::basic_attestation("MyAttestation");

// Generate code for identity verification
let code = presets::identity_attestation("IdentityAttestation");

// Generate custom code using builder
let code = generator::generate_custom_abi_provider(
    "CustomStruct",
    array![
        ("field1", "ContractAddress", 32),
        ("field2", "felt252", 32),
        ("field3", "u64", 8),
    ]
);
```

### Real-world Examples

#### Education Credential System
```cairo
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct EducationCredential {
    pub university: ContractAddress,
    pub graduate: ContractAddress,
    pub degree_level: felt252,      // 'bachelor', 'master', 'phd'
    pub field_of_study: felt252,
    pub graduation_date: u64,
    pub gpa: u64,                   // GPA * 100
    pub honors: bool,
}

let edu_provider = derive_utils::derive_custom::<EducationCredential>("EducationCredential")
    .contract_address("university")
    .contract_address("graduate")
    .felt252("degree_level")
    .felt252("field_of_study")
    .u64("graduation_date")
    .u64("gpa")
    .bool("honors")
    .build();
```

#### Identity Verification System
```cairo
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct IdentityVerification {
    pub kyc_provider: ContractAddress,
    pub user: ContractAddress,
    pub document_hash: felt252,
    pub verification_level: u64,    // 1=basic, 2=enhanced, 3=premium
    pub country_code: felt252,
    pub expiry_date: u64,
    pub is_active: bool,
}

let id_provider = derive_utils::derive_custom::<IdentityVerification>("IdentityVerification")
    .contract_address("kyc_provider")
    .contract_address("user")
    .felt252("document_hash")
    .u64("verification_level")
    .felt252("country_code")
    .u64("expiry_date")
    .bool("is_active")
    .build();
```

### Batch Processing with Derive

Process multiple attestations efficiently:

```cairo
// Create multiple attestations
let attestations = array![
    EducationCredential { /* ... */ },
    EducationCredential { /* ... */ },
    EducationCredential { /* ... */ },
];

// Process all with same ABI provider
let abi_provider = derive_utils::derive_custom::<EducationCredential>("EducationCredential")
    /* field definitions */
    .build();

let mut i = 0;
loop {
    if i >= attestations.len() { break; }
    let serialized = abi_provider.serialize_to_array(attestations.at(i).clone());
    println!("Attestation {}: {} elements", i, serialized.len());
    i += 1;
};
```

## Technical Details

- **Serialization**: Uses Cairo's built-in `Serde` trait for automatic serialization
- **Type Safety**: All ABI information is type-safe and compile-time verified
- **Gas Efficiency**: Optimized for minimal gas usage in on-chain operations
- **Modularity**: Clean separation between data structures, ABI utilities, and contract interface

## Best Practices

### 1. Use Derive-like Generation
Always prefer the derive-like utilities over manual implementations:

```cairo
// ✅ Good: Use derive utilities
let provider = derive_utils::derive_custom::<MyStruct>("MyStruct")
    .contract_address("field1")
    .felt252("field2")
    .build();

// ❌ Avoid: Manual implementation unless necessary
impl MyStructABIProvider of ABIProvider<MyStruct> { /* ... */ }
```

### 2. Consistent Naming
Use clear, descriptive names for your attestation types:

```cairo
// ✅ Good: Descriptive names
EducationCredentialAttestation
IdentityVerificationAttestation
ReputationScoreAttestation

// ❌ Avoid: Vague names
DataAttestation
InfoAttestation
GenericAttestation
```

### 3. Validate Generated ABIs
Always validate your generated ABIs:

```cairo
let abi = abi_provider.get_abi();
assert(abi.fields.len() > 0, 'ABI has no fields');
assert(abi.name.len() > 0, 'ABI has no name');
```

### 4. Test Serialization
Verify that your structs serialize correctly:

```cairo
let attestation = MyAttestation { /* ... */ };
let serialized = abi_provider.serialize_to_array(attestation);
assert(serialized.len() > 0, 'Serialization failed');
```

## Contributing

This project serves as a foundation for attestation systems. Feel free to extend it with:

- Additional attestation schemas using derive patterns
- More sophisticated ABI introspection capabilities
- Integration with attestation standards (EAS, etc.)
- Enhanced validation mechanisms
- Performance optimizations for large-scale deployments
- Additional derive patterns for specialized use cases

### Development Workflow

1. Define your attestation struct with `#[derive(Drop, Serde, Clone, PartialEq)]`
2. Use `derive_utils::derive_custom()` to generate ABI provider
3. Test with sample data and validate ABI output
4. Integrate with smart contracts if needed
5. Add comprehensive tests and documentation

## License

This project is provided as an example for educational and development purposes.