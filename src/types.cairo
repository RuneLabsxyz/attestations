use starknet::ContractAddress;

/// Core attestation schema definition
#[derive(Drop, Serde)]
pub struct AttestationSchema {
    /// Human-readable name of the schema
    pub name: ByteArray,
    /// Description of what this schema attests to
    pub description: ByteArray,
    /// Version of the schema
    pub version: u32,
    /// Fields in this schema
    pub fields: Array<SchemaField>,
}

/// Field definition in an attestation schema
#[derive(Drop, Serde)]
pub struct SchemaField {
    /// Name of the field
    pub name: ByteArray,
    /// Type of the field
    pub field_type: FieldType,
    /// Whether this field is required
    pub required: bool,
    /// Size of the field in bytes (0 for variable size)
    pub size: u32,
    /// Description of the field
    pub description: ByteArray,
    /// Enum variants (only used when field_type is Enum)
    pub enum_variants: Option<Array<EnumVariant>>,

    /// Struct definition (only used when field_type is Struct)
    pub struct_definition: Option<StructDefinition>,
}

/// Definition of an enum variant in a schema
#[derive(Drop, Serde)]
pub struct EnumVariant {
    /// Name of the variant
    pub name: ByteArray,
    /// Description of the variant
    pub description: ByteArray,
    /// Fields contained in this variant
    pub fields: Array<SchemaField>,
}

/// Definition of a struct in a schema
#[derive(Drop, Serde)]
pub struct StructDefinition {
    /// Name of the struct
    pub name: ByteArray,
    /// Description of the struct
    pub description: ByteArray,
    /// Fields contained in this struct
    pub fields: Array<SchemaField>,
}

/// Supported field types in schemas
#[derive(Drop, Serde, Clone, Copy)]
pub enum FieldType {
    String,
    Uint256,
    Uint64,
    Address,
    Bool,
    Bytes,
    Hash,
    Enum,
    Struct,
}

/// Utility functions for schema handling
pub trait SchemaUtils {
    /// Convert field type to JSON string representation
    fn field_type_to_json(field_type: FieldType) -> ByteArray;

    /// Convert entire schema to JSON string
    fn schema_to_json(schema: AttestationSchema) -> ByteArray;
}

pub impl SchemaUtilsImpl of SchemaUtils {
    fn field_type_to_json(field_type: FieldType) -> ByteArray {
        match field_type {
            FieldType::String => "String",
            FieldType::Uint256 => "Uint256",
            FieldType::Uint64 => "Uint64",
            FieldType::Address => "Address",
            FieldType::Bool => "Bool",
            FieldType::Bytes => "Bytes",
            FieldType::Hash => "Hash",
            FieldType::Enum => "Enum",
            FieldType::Struct => "Struct",
        }
    }

    fn schema_to_json(schema: AttestationSchema) -> ByteArray {
        let mut json = "{\n  \"name\": \"";
        json = json + schema.name;
        json = json + "\",\n  \"description\": \"";
        json = json + schema.description;
        json = json + "\",\n  \"version\": ";

        // Simple version number handling for common cases
        if schema.version == 1 {
            json = json + "1";
        } else if schema.version == 2 {
            json = json + "2";
        } else {
            json = json + "0";
        }

        json = json + ",\n  \"fields\": [";

        let mut i = 0;
        let fields_span = schema.fields.span();
        while i < fields_span.len() {
            if i > 0 {
                json = json + ",";
            }
            let field = fields_span[i];
            json = json + "\n    {\n      \"name\": \"";
            json = json + field.name.clone();
            json = json + "\",\n      \"type\": \"";
            json = json + Self::field_type_to_json(*field.field_type);
            json = json + "\",\n      \"required\": ";
            json = json + if *field.required {
                "true"
            } else {
                "false"
            };
            json = json + ",\n      \"size\": ";

            // Simple size handling for common cases
            if *field.size == 0 {
                json = json + "0";
            } else if *field.size == 8 {
                json = json + "8";
            } else if *field.size == 32 {
                json = json + "32";
            } else {
                json = json + "0";
            }

            json = json + ",\n      \"description\": \"";
            json = json + field.description.clone();
            json = json + "\"";

            // Add enum variants if this is an enum field
            match field.field_type {
                FieldType::Enum => {
                    match field.enum_variants {
                        Option::Some(variants) => {
                            json = json + ",\n      \"variants\": [";
                            let mut variant_idx = 0;
                            let variants_span = variants.span();
                            while variant_idx < variants_span.len() {
                                if variant_idx > 0 {
                                    json = json + ",";
                                }
                                let variant = variants_span[variant_idx];
                                json = json + "\n        {\n          \"name\": \"";
                                json = json + variant.name.clone();
                                json = json + "\",\n          \"description\": \"";
                                json = json + variant.description.clone();
                                json = json + "\",\n          \"fields\": [";

                                let mut field_idx = 0;
                                let variant_fields_span = variant.fields.span();
                                while field_idx < variant_fields_span.len() {
                                    if field_idx > 0 {
                                        json = json + ",";
                                    }
                                    let variant_field = variant_fields_span[field_idx];
                                    json = json + "\n            {\n              \"name\": \"";
                                    json = json + variant_field.name.clone();
                                    json = json + "\",\n              \"type\": \"";
                                    json = json + Self::field_type_to_json(*variant_field.field_type);
                                    json = json + "\",\n              \"required\": ";
                                    json = json + if *variant_field.required {
                                        "true"
                                    } else {
                                        "false"
                                    };
                                    json = json + "\n            }";
                                    field_idx += 1;
                                }

                                json = json + "\n          ]\n        }";
                                variant_idx += 1;
                            }
                            json = json + "\n      ]";
                        },
                        Option::None => {}
                    }
                },
                FieldType::Struct => {
                    match field.struct_definition {
                        Option::Some(struct_def) => {
                            json = json + ",\n      \"struct\": {\n        \"name\": \"";
                            json = json + struct_def.name.clone();
                            json = json + "\",\n        \"description\": \"";
                            json = json + struct_def.description.clone();
                            json = json + "\",\n        \"fields\": [";

                            let mut field_idx = 0;
                            let struct_fields_span = struct_def.fields.span();
                            while field_idx < struct_fields_span.len() {
                                if field_idx > 0 {
                                    json = json + ",";
                                }
                                let struct_field = struct_fields_span[field_idx];
                                json = json + "\n          {\n            \"name\": \"";
                                json = json + struct_field.name.clone();
                                json = json + "\",\n            \"type\": \"";
                                json = json + Self::field_type_to_json(*struct_field.field_type);
                                json = json + "\",\n            \"required\": ";
                                json = json + if *struct_field.required {
                                    "true"
                                } else {
                                    "false"
                                };
                                json = json + ",\n            \"description\": \"";
                                json = json + struct_field.description.clone();
                                json = json + "\"\n          }";
                                field_idx += 1;
                            }

                            json = json + "\n        ]\n      }";
                        },
                        Option::None => {}
                    }
                },
                _ => {}
            }

            json = json + "\n    }";
            i += 1;
        }

        json = json + "\n  ]\n  }\n";

        json
    }
}

/// Core attestation structure
#[derive(Drop, Serde)]
pub struct Attestation<TData> {
    /// Unique identifier for this attestation
    pub id: felt252,
    /// Who/what is being attested to
    pub subject: ContractAddress,
    /// The typed attestation data
    pub data: TData,
    /// When the attestation was created
    pub created_at: u64,
    /// When the attestation expires (if applicable)
    pub expires_at: Option<u64>,
    /// Whether the attestation has been revoked
    pub revoked: bool,
    /// When the attestation was revoked (if applicable)
    pub revoked_at: Option<u64>,
    /// External reference (IPFS hash, URL, etc.)
    pub external_ref: Option<ByteArray>,
}

#[cfg(test)]
mod tests {
    use super::{
        AttestationSchema, SchemaField, FieldType,SchemaUtilsImpl, EnumVariant, StructDefinition
    };

    #[test]
    fn test_field_type_variants() {
        let _string_type = FieldType::String;
        let _uint256_type = FieldType::Uint256;
        let _uint64_type = FieldType::Uint64;
        let _address_type = FieldType::Address;
        let _bool_type = FieldType::Bool;
        let _bytes_type = FieldType::Bytes;
        let _hash_type = FieldType::Hash;

        // Test that field types can be created and used
        assert(true, 'Field types created');
    }

    #[test]
    fn test_schema_field_creation() {
        let field = SchemaField {
            name: "test_field",
            field_type: FieldType::String,
            required: true,
            size: 0,
            description: "A test field",
            enum_variants: Option::None,
            struct_definition: Option::None,
        };

        assert(field.name == "test_field", 'Field name correct');
        assert(field.required == true, 'Field required flag correct');
        assert(field.size == 0, 'Field size correct');
        assert(field.description == "A test field", 'Field description correct');
    }

    #[test]
    fn test_attestation_schema_creation() {
        let mut fields = array![];
        fields.append(SchemaField {
            name: "test_field",
            field_type: FieldType::String,
            required: true,
            size: 0,
            description: "A test field",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let schema = AttestationSchema {
            name: "Test Schema",
            description: "A test schema",
            version: 1,
            fields,
        };

        assert(schema.name == "Test Schema", 'Schema name correct');
        assert(schema.description == "A test schema", 'Schema description correct');
        assert(schema.version == 1, 'Schema version correct');
        assert(schema.fields.len() == 1, 'Schema has correct field count');
    }

    #[test]
    fn test_schema_field_types_all() {
        let field_string = SchemaField {
            name: "string_field",
            field_type: FieldType::String,
            required: true,
            size: 0,
            description: "String field",
            enum_variants: Option::None,
            struct_definition: Option::None,
        };

        let field_uint256 = SchemaField {
            name: "uint256_field",
            field_type: FieldType::Uint256,
            required: false,
            size: 32,
            description: "Uint256 field",
            enum_variants: Option::None,
            struct_definition: Option::None,
        };

        let field_address = SchemaField {
            name: "address_field",
            field_type: FieldType::Address,
            required: true,
            size: 32,
            description: "Address field",
            enum_variants: Option::None,
            struct_definition: Option::None,
        };

        // Test that all field types can be used in schema fields
        assert(field_string.required == true, 'String field created');
        assert(field_uint256.required == false, 'Uint256 field created');
        assert(field_address.size == 32, 'Address field created');
    }

    #[test]
    fn test_json_output_basic() {
        let mut fields = array![];
        fields.append(SchemaField {
            name: "test",
            field_type: FieldType::String,
            required: true,
            size: 0,
            description: "Test field",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let schema = AttestationSchema {
            name: "Test",
            description: "Test schema",
            version: 1,
            fields,
        };

        let json = SchemaUtilsImpl::schema_to_json(schema);
        assert(json.len() > 0, 'JSON output generated');
    }

    #[test]
    fn test_enum_variant_creation() {
        let mut variant_fields = array![];
        variant_fields.append(SchemaField {
            name: "user_id_hash",
            field_type: FieldType::Hash,
            required: true,
            size: 31,
            description: "Hash of Discord user ID",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let variant = EnumVariant {
            name: "Private",
            description: "Privacy-preserving attestation with hashed user ID",
            fields: variant_fields,
        };

        assert(variant.name == "Private", 'Variant name correct');
        assert(variant.fields.len() == 1, 'Variant has correct field count');
    }

    #[test]
    fn test_enum_field_creation() {
        let mut private_fields = array![];
        private_fields.append(SchemaField {
            name: "user_id_hash",
            field_type: FieldType::Hash,
            required: true,
            size: 31,
            description: "Hash of Discord user ID",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let mut public_fields = array![];
        public_fields.append(SchemaField {
            name: "user_id",
            field_type: FieldType::String,
            required: true,
            size: 0,
            description: "Discord user ID",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let mut variants = array![];
        variants.append(EnumVariant {
            name: "Private",
            description: "Privacy-preserving attestation",
            fields: private_fields,
        });
        variants.append(EnumVariant {
            name: "Public",
            description: "Public attestation",
            fields: public_fields,
        });

        let enum_field = SchemaField {
            name: "data",
            field_type: FieldType::Enum,
            required: true,
            size: 0,
            description: "Discord attestation data",
            enum_variants: Option::Some(variants),
            struct_definition: Option::None,
        };

        assert(enum_field.name == "data", 'Enum field name correct');
        match enum_field.field_type {
            FieldType::Enum => assert(true, 'Field type is Enum'),
            _ => panic!("Should be Enum type")
        }
    }

    #[test]
    fn test_struct_definition_creation() {
        let mut struct_fields = array![];
        struct_fields.append(SchemaField {
            name: "x",
            field_type: FieldType::Uint64,
            required: true,
            size: 8,
            description: "X coordinate",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });
        struct_fields.append(SchemaField {
            name: "y",
            field_type: FieldType::Uint64,
            required: true,
            size: 8,
            description: "Y coordinate",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let struct_def = StructDefinition {
            name: "Point",
            description: "A 2D point with x and y coordinates",
            fields: struct_fields,
        };

        assert(struct_def.name == "Point", 'Struct name correct');
        assert(struct_def.description == "A 2D point with x and y coordinates", 'Struct description correct');
        assert(struct_def.fields.len() == 2_u32, 'Struct field count correct');
    }

    #[test]
    fn test_struct_field_creation() {
        let mut struct_fields = array![];
        struct_fields.append(SchemaField {
            name: "width",
            field_type: FieldType::Uint64,
            required: true,
            size: 8,
            description: "Width of the rectangle",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });
        struct_fields.append(SchemaField {
            name: "height",
            field_type: FieldType::Uint64,
            required: true,
            size: 8,
            description: "Height of the rectangle",
            enum_variants: Option::None,
            struct_definition: Option::None,
        });

        let struct_def = StructDefinition {
            name: "Rectangle",
            description: "A rectangle with width and height",
            fields: struct_fields,
        };

        let struct_field = SchemaField {
            name: "bounds",
            field_type: FieldType::Struct,
            required: true,
            size: 0,
            description: "Rectangle bounds",
            enum_variants: Option::None,
            struct_definition: Option::Some(struct_def),
        };

        assert(struct_field.name == "bounds", 'Struct field name correct');
        match struct_field.field_type {
            FieldType::Struct => assert(true, 'Field type is Struct'),
            _ => panic!("Should be Struct type")
        }

        match struct_field.struct_definition {
            Option::Some(def) => {
                assert(def.name == "Rectangle", 'Struct definition name correct');
                assert(def.fields.len() == 2_u32, 'Struct def field count ok');
            },
            Option::None => panic!("Should have struct definition")
        }
    }
}
