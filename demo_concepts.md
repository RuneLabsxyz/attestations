# Cairo Attestation ABI Concepts Demo

This document demonstrates the key concepts of how the Cairo Attestation ABI library works, showing the data structures and operations without requiring compilation.

## Core Data Structure

The `AttestationData` struct represents a complete attestation with the following fields:

```cairo
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct AttestationData {
    pub attester: ContractAddress,      // 32 bytes - Who made the attestation
    pub subject: ContractAddress,       // 32 bytes - Who/what is being attested
    pub schema_id: felt252,            // 32 bytes - Type of attestation
    pub data: ByteArray,               // Variable - The actual attestation payload
    pub timestamp: u64,                // 8 bytes - When it was created
    pub expiration: u64,               // 8 bytes - When it expires (0 = never)
    pub revocable: bool,               // 1 byte - Can it be revoked?
    pub ref_attestation: felt252,      // 32 bytes - Reference to another attestation
}
```

## ABI Extraction Process

### 1. Field Information Structure

Each field in the struct is represented by an `ABIField`:

```cairo
pub struct ABIField {
    pub name: ByteArray,        // Field name (e.g., "attester")
    pub field_type: ByteArray,  // Field type (e.g., "ContractAddress")
    pub size_bytes: u32,        // Size in bytes (e.g., 32)
}
```

### 2. Complete ABI Structure

The complete ABI is represented by `StructABI`:

```cairo
pub struct StructABI {
    pub name: ByteArray,           // Struct name ("AttestationData")
    pub fields: Array<ABIField>,   // Array of all fields
    pub total_size: u32,           // Total size of fixed-size fields
}
```

## Example ABI Output

When you call `get_abi()` on an `AttestationData`, you get this structure:

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

## Serialization Process

### Input Attestation
```cairo
AttestationData {
    attester: 0x1234...5678,
    subject: 0xABCD...EFGH,
    schema_id: 'identity_verification',
    data: "verified_identity_hash_abc123",
    timestamp: 1703980800,
    expiration: 0,
    revocable: true,
    ref_attestation: 0,
}
```

### Serialized Output (felt252 array)
```
[
    0x1234...5678,                    // attester (felt252)
    0xABCD...EFGH,                    // subject (felt252)
    0x6964656E746974795F766572696669,  // 'identity_verification' (felt252)
    26,                               // data length
    0x766572696669656420696465,       // data chunk 1
    0x6E746974795F686173685F616263,   // data chunk 2
    0x313233,                         // data chunk 3 (final)
    1703980800,                       // timestamp (u64 as felt252)
    0,                                // expiration (u64 as felt252)
    1,                                // revocable (bool as felt252)
    0,                                // ref_attestation (felt252)
]
```

## Key Operations Demonstrated

### 1. ABI Generation
```cairo
// Get complete ABI structure
let abi = AttestationDataABIProvider::get_abi();
assert(abi.name == "AttestationData");
assert(abi.fields.len() == 8);
```

### 2. Field Lookup
```cairo
// Find specific field by name
let field = abi_utils::get_field_by_name(abi, "timestamp");
match field {
    Option::Some(f) => println!("Found: {} bytes", f.size_bytes),
    Option::None => println!("Field not found"),
}
```

### 3. Serialization
```cairo
// Convert struct to felt252 array
let attestation = create_sample_attestation();
let serialized = AttestationDataABIProvider::serialize_to_array(attestation);
println!("Serialized to {} elements", serialized.len());
```

### 4. JSON-like Output
```cairo
// Convert ABI to readable string format
let abi_string = abi_utils::abi_to_string(abi);
// Results in the JSON structure shown above
```

## Use Cases for Attestation ABIs

### 1. Schema Validation
Before accepting an attestation, verify it matches expected structure:
```cairo
fn validate_attestation_schema(data: Array<felt252>) -> bool {
    let mut span = data.span();
    let result: Result<AttestationData, Array<felt252>> = Serde::deserialize(ref span);
    result.is_ok()
}
```

### 2. Dynamic Field Access
Access fields by name without hardcoding positions:
```cairo
fn get_field_value(abi: StructABI, field_name: ByteArray, data: Array<felt252>) -> Option<felt252> {
    let field_info = abi_utils::get_field_by_name(abi, field_name);
    match field_info {
        Option::Some(field) => {
            // Calculate field position and extract value
            // Implementation depends on field type and position
            Option::Some(*data.at(calculate_field_position(field)))
        },
        Option::None => Option::None,
    }
}
```

### 3. Multi-Schema Support
Handle different attestation types with same interface:
```cairo
fn process_attestation(schema_id: felt252, data: Array<felt252>) -> bool {
    match schema_id {
        'identity_verification' => validate_identity_attestation(data),
        'email_verification' => validate_email_attestation(data),
        'age_verification' => validate_age_attestation(data),
        _ => false,
    }
}
```

### 4. Off-chain Integration
Generate ABI information for off-chain systems:
```cairo
// Contract function to expose ABI to external systems
fn get_attestation_abi_for_integration() -> ByteArray {
    let abi = AttestationDataABIProvider::get_abi();
    abi_utils::abi_to_string(abi)
}
```

## Smart Contract Integration

The library includes a smart contract that provides on-chain access to ABI information:

### Contract Interface
- `get_attestation_abi()` - Returns complete ABI structure
- `get_abi_as_string()` - Returns JSON-like ABI string
- `create_and_serialize_attestation()` - Creates and serializes new attestation
- `get_field_info(field_name)` - Gets information about specific field
- `validate_attestation_format(data)` - Validates serialized attestation format

### Events
- `AttestationCreated` - Emitted when new attestation is created
- `ABIRequested` - Emitted when ABI information is requested

## Advanced Features

### 1. Batch Processing
Process multiple attestations with same ABI:
```cairo
fn process_attestation_batch(attestations: Array<AttestationData>) -> Array<Array<felt252>> {
    let mut serialized_batch = array![];
    let mut i = 0;
    loop {
        if i >= attestations.len() { break; }
        let attestation = attestations.at(i);
        let serialized = AttestationDataABIProvider::serialize_to_array(attestation.clone());
        serialized_batch.append(serialized);
        i += 1;
    };
    serialized_batch
}
```

### 2. Custom Attestation Types
Extend the library for custom schemas by implementing `ABIProvider` trait:
```cairo
impl CustomAttestationABIProvider of ABIProvider<CustomAttestation> {
    fn get_abi() -> StructABI { /* custom implementation */ }
    fn get_field_count() -> u32 { /* custom implementation */ }
    fn serialize_to_array(self: CustomAttestation) -> Array<felt252> { /* custom implementation */ }
}
```

## Benefits of This Approach

1. **Type Safety**: ABI information is generated from actual struct definitions
2. **Runtime Introspection**: Access field information at runtime
3. **Serialization Consistency**: Automatic serialization through Serde trait
4. **Interoperability**: Standard ABI format for cross-system integration
5. **Validation**: Built-in validation of attestation format
6. **Extensibility**: Easy to add new attestation types

This demonstrates how Cairo's type system and serialization capabilities can be leveraged to create powerful attestation systems with full ABI introspection support.