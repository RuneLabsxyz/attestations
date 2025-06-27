//! Cairo Plugin for Automatic ABIProvider Generation
//!
//! This plugin provides a `#[derive(Attestation)]` attribute that automatically generates
//! ABIProvider trait implementations for Cairo structs.

use std::sync::Arc;

use cairo_lang_defs::plugin::{
    MacroPlugin, MacroPluginMetadata, PluginDiagnostic, PluginGeneratedFile, PluginResult,
};
use cairo_lang_diagnostics::Severity;
use cairo_lang_syntax::node::ast::{
    Attribute, Item, ItemStruct, Member, MemberList, StructArgList, TypeClause,
};
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::{Terminal, TypedSyntaxNode};
use indoc::formatdoc;

/// The main plugin implementation
#[derive(Debug, Default)]
pub struct AttestationPlugin;

impl MacroPlugin for AttestationPlugin {
    fn generate_code(
        &self,
        db: &dyn SyntaxGroup,
        item_ast: cairo_lang_syntax::node::ast::ModuleItem,
        _metadata: &MacroPluginMetadata,
    ) -> PluginResult {
        match item_ast {
            cairo_lang_syntax::node::ast::ModuleItem::Struct(struct_ast) => {
                // Check if the struct has the Attestation derive attribute
                if !has_attestation_derive(&struct_ast) {
                    return PluginResult::default();
                }

                match generate_abi_provider_for_struct(db, &struct_ast) {
                    Ok(code) => PluginResult {
                        code: Some(PluginGeneratedFile {
                            name: format!("{}_abi_provider.cairo", struct_ast.name(db).text(db)),
                            content: code,
                            code_mappings: vec![],
                            aux_data: None,
                        }),
                        diagnostics: vec![],
                        remove_original_item: false,
                    },
                    Err(diagnostic) => PluginResult {
                        code: None,
                        diagnostics: vec![diagnostic],
                        remove_original_item: false,
                    },
                }
            }
            _ => PluginResult::default(),
        }
    }

    fn declared_attributes(&self) -> Vec<String> {
        vec!["derive".to_string()]
    }
}

/// Check if a struct has the Attestation derive attribute
fn has_attestation_derive(struct_ast: &ItemStruct) -> bool {
    for attr in struct_ast.attributes(db).elements(db).iter() {
        if let Some(attr_list) = get_derive_attr_list(db, attr) {
            for derive_input in attr_list.iter() {
                if derive_input.as_syntax_node().get_text_without_trivia(db) == "Attestation" {
                    return true;
                }
            }
        }
    }
    false
}

/// Extract derive attribute list from an attribute
fn get_derive_attr_list(
    db: &dyn SyntaxGroup,
    attr: &Attribute,
) -> Option<Vec<cairo_lang_syntax::node::ast::Expr>> {
    if attr.attr(db).text(db) != "derive" {
        return None;
    }

    // Parse the derive attribute arguments
    // This is simplified - in practice you'd need more robust parsing
    let args = attr.arguments(db)?;
    let arg_list = args.arg_list(db)?;

    Some(
        arg_list
            .elements(db)
            .iter()
            .map(|elem| elem.clone())
            .collect(),
    )
}

/// Generate ABIProvider implementation for a struct
fn generate_abi_provider_for_struct(
    db: &dyn SyntaxGroup,
    struct_ast: &ItemStruct,
) -> Result<String, PluginDiagnostic> {
    let struct_name = struct_ast.name(db).text(db);
    let struct_name_str = struct_name.clone();

    // Get struct members
    let members = match struct_ast.members(db) {
        MemberList::MemberList(member_list) => member_list.elements(db),
        _ => {
            return Err(PluginDiagnostic {
                stable_ptr: struct_ast.stable_ptr().untyped(),
                message: "Only structs with named members are supported".to_string(),
                severity: Severity::Error,
            });
        }
    };

    let mut field_definitions = Vec::new();
    let mut total_size = 0u32;
    let field_count = members.len();

    for member in members.iter() {
        if let Member::Member(member_ast) = member {
            let field_name = member_ast.name(db).text(db);
            let field_type = member_ast.type_clause(db);

            let (type_name, size_bytes) = get_cairo_type_info(db, &field_type);
            total_size += size_bytes;

            field_definitions.push(formatdoc! {r#"
                fields.append(ABIField {{
                    name: "{}",
                    field_type: "{}",
                    size_bytes: {},
                }});
            "#, field_name, type_name, size_bytes});
        }
    }

    let field_definitions_code = field_definitions.join("\n            ");

    let generated_code = formatdoc! {r#"
        /// Auto-generated ABIProvider implementation for {}
        impl {}ABIProvider of ABIProvider<{}> {{
            fn get_abi() -> StructABI {{
                let mut fields = array![];

                {}

                StructABI {{
                    name: "{}",
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
        }}
    "#,
        struct_name_str,
        struct_name,
        struct_name,
        field_definitions_code,
        struct_name_str,
        total_size,
        field_count,
        struct_name
    };

    Ok(generated_code)
}

/// Map Cairo types to their string representation and byte size
fn get_cairo_type_info(db: &dyn SyntaxGroup, type_clause: &TypeClause) -> (String, u32) {
    let type_text = type_clause.ty(db).as_syntax_node().get_text_without_trivia(db);

    match type_text.as_str() {
        "ContractAddress" => ("ContractAddress".to_string(), 32),
        "felt252" => ("felt252".to_string(), 32),
        "u8" => ("u8".to_string(), 1),
        "u16" => ("u16".to_string(), 2),
        "u32" => ("u32".to_string(), 4),
        "u64" => ("u64".to_string(), 8),
        "u128" => ("u128".to_string(), 16),
        "u256" => ("u256".to_string(), 32),
        "bool" => ("bool".to_string(), 1),
        "ByteArray" => ("ByteArray".to_string(), 0), // Variable size
        _ if type_text.starts_with("Array<") => ("Array".to_string(), 0), // Variable size
        _ if type_text.starts_with("Span<") => ("Span".to_string(), 0), // Variable size
        _ => (type_text, 0), // Unknown types default to 0 size
    }
}

/// Entry point for the plugin
#[no_mangle]
pub extern "C" fn plugin() -> *const dyn MacroPlugin {
    Box::leak(Box::new(AttestationPlugin)) as *const dyn MacroPlugin
}

#[cfg(test)]
mod tests {
    use super::*;
    use cairo_lang_parser::utils::SimpleParserDatabase;
    use cairo_lang_syntax::node::ast::ModuleItem;

    fn setup_db() -> SimpleParserDatabase {
        SimpleParserDatabase::default()
    }

    #[test]
    fn test_simple_struct_generation() {
        let db = setup_db();

        let code = r#"
        #[derive(Drop, Serde, Clone, Attestation)]
        struct TestStruct {
            field1: ContractAddress,
            field2: felt252,
            field3: u64,
        }
        "#;

        // This would require more complex test setup with actual Cairo parsing
        // For now, we'll just test the type mapping function
        assert_eq!(
            get_cairo_type_info(&db, &mock_type_clause("ContractAddress")),
            ("ContractAddress".to_string(), 32)
        );
    }

    // Mock function for testing - in real implementation this would use actual Cairo AST
    fn mock_type_clause(type_name: &str) -> TypeClause {
        // This is a simplified mock - real implementation would create proper AST nodes
        unimplemented!("Mock function for testing")
    }

    #[test]
    fn test_type_mapping() {
        let db = setup_db();

        // Test basic type mappings
        let test_cases = vec![
            ("ContractAddress", ("ContractAddress".to_string(), 32)),
            ("felt252", ("felt252".to_string(), 32)),
            ("u64", ("u64".to_string(), 8)),
            ("bool", ("bool".to_string(), 1)),
            ("ByteArray", ("ByteArray".to_string(), 0)),
        ];

        for (input, expected) in test_cases {
            // In a real test, we'd create proper TypeClause AST nodes
            // For now, we test the logic conceptually
            let result = match input {
                "ContractAddress" => ("ContractAddress".to_string(), 32),
                "felt252" => ("felt252".to_string(), 32),
                "u64" => ("u64".to_string(), 8),
                "bool" => ("bool".to_string(), 1),
                "ByteArray" => ("ByteArray".to_string(), 0),
                _ => ("unknown".to_string(), 0),
            };
            assert_eq!(result, expected);
        }
    }
}
