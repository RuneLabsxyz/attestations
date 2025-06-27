//! Procedural macro for automatically deriving ABIProvider implementations
//!
//! This crate provides a `#[derive(Attestation)]` macro that automatically generates
//! the `ABIProvider` trait implementation for Cairo structs, extracting field information
//! and providing serialization capabilities.

use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, Data, DeriveInput, Fields, Type};

/// Derive macro for automatically implementing ABIProvider
///
/// Usage:
/// ```cairo
/// #[derive(Drop, Serde, Clone, Attestation)]
/// pub struct MyAttestation {
///     pub field1: ContractAddress,
///     pub field2: felt252,
///     pub field3: u64,
/// }
/// ```
#[proc_macro_derive(Attestation)]
pub fn derive_attestation(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    match generate_abi_provider(&input) {
        Ok(tokens) => tokens.into(),
        Err(err) => err.to_compile_error().into(),
    }
}

fn generate_abi_provider(input: &DeriveInput) -> syn::Result<proc_macro2::TokenStream> {
    let struct_name = &input.ident;
    let struct_name_str = struct_name.to_string();

    let fields = match &input.data {
        Data::Struct(data_struct) => match &data_struct.fields {
            Fields::Named(fields_named) => &fields_named.named,
            _ => return Err(syn::Error::new_spanned(
                input,
                "Only structs with named fields are supported"
            )),
        },
        _ => return Err(syn::Error::new_spanned(
            input,
            "Only structs are supported"
        )),
    };

    let field_count = fields.len();

    // Generate ABI field definitions
    let abi_fields = fields.iter().map(|field| {
        let field_name = field.ident.as_ref().unwrap().to_string();
        let field_type = &field.ty;
        let (type_name, size_bytes) = get_type_info(field_type);

        quote! {
            fields.append(ABIField {
                name: #field_name,
                field_type: #type_name,
                size_bytes: #size_bytes,
            });
        }
    });

    // Calculate total size of fixed-size fields
    let total_size_calculation = fields.iter().map(|field| {
        let field_type = &field.ty;
        let (_, size_bytes) = get_type_info(field_type);
        size_bytes
    }).sum::<u32>();

    // Generate the implementation name
    let impl_name = syn::Ident::new(
        &format!("{}ABIProvider", struct_name),
        struct_name.span()
    );

    let expanded = quote! {
        impl #impl_name of ABIProvider<#struct_name> {
            fn get_abi() -> StructABI {
                let mut fields = array![];

                #(#abi_fields)*

                StructABI {
                    name: #struct_name_str,
                    fields,
                    total_size: #total_size_calculation,
                }
            }

            fn get_field_count() -> u32 {
                #field_count
            }

            fn serialize_to_array(self: #struct_name) -> Array<felt252> {
                let mut serialized = array![];
                self.serialize(ref serialized);
                serialized
            }
        }
    };

    Ok(expanded)
}

/// Map Cairo types to their string representation and byte size
fn get_type_info(ty: &Type) -> (&'static str, u32) {
    match ty {
        Type::Path(type_path) => {
            let path = &type_path.path;
            if let Some(segment) = path.segments.last() {
                match segment.ident.to_string().as_str() {
                    "ContractAddress" => ("ContractAddress", 32),
                    "felt252" => ("felt252", 32),
                    "u8" => ("u8", 1),
                    "u16" => ("u16", 2),
                    "u32" => ("u32", 4),
                    "u64" => ("u64", 8),
                    "u128" => ("u128", 16),
                    "u256" => ("u256", 32),
                    "bool" => ("bool", 1),
                    "ByteArray" => ("ByteArray", 0), // Variable size
                    "Array" => ("Array", 0), // Variable size
                    "Span" => ("Span", 0), // Variable size
                    _ => ("unknown", 0),
                }
            } else {
                ("unknown", 0)
            }
        },
        _ => ("unknown", 0),
    }
}

/// Attribute macro for custom ABI configuration
///
/// Usage:
/// ```cairo
/// #[attestation_abi(name = "CustomName", version = "1.0")]
/// #[derive(Drop, Serde, Clone, Attestation)]
/// pub struct MyAttestation {
///     #[abi_field(description = "The attester address")]
///     pub attester: ContractAddress,
/// }
/// ```
#[proc_macro_attribute]
pub fn attestation_abi(args: TokenStream, input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    // For now, just pass through - could extend with custom attributes
    quote! { #input }.into()
}

/// Helper macro for creating ABI field with custom metadata
#[proc_macro]
pub fn abi_field(input: TokenStream) -> TokenStream {
    // This could be extended to handle custom field metadata
    input
}

#[cfg(test)]
mod tests {
    use super::*;
    use quote::quote;
    use syn::parse_quote;

    #[test]
    fn test_simple_struct() {
        let input: DeriveInput = parse_quote! {
            pub struct TestStruct {
                pub field1: ContractAddress,
                pub field2: felt252,
                pub field3: u64,
            }
        };

        let result = generate_abi_provider(&input);
        assert!(result.is_ok());

        let tokens = result.unwrap();
        let generated = tokens.to_string();

        assert!(generated.contains("TestStructABIProvider"));
        assert!(generated.contains("field1"));
        assert!(generated.contains("ContractAddress"));
        assert!(generated.contains("get_field_count"));
    }

    #[test]
    fn test_field_count() {
        let input: DeriveInput = parse_quote! {
            pub struct TestStruct {
                pub field1: ContractAddress,
                pub field2: felt252,
            }
        };

        let result = generate_abi_provider(&input);
        assert!(result.is_ok());

        let tokens = result.unwrap();
        let generated = tokens.to_string();

        assert!(generated.contains("2"));
    }

    #[test]
    fn test_unsupported_enum() {
        let input: DeriveInput = parse_quote! {
            pub enum TestEnum {
                Variant1,
                Variant2,
            }
        };

        let result = generate_abi_provider(&input);
        assert!(result.is_err());
    }

    #[test]
    fn test_type_mapping() {
        assert_eq!(get_type_info(&parse_quote!(ContractAddress)), ("ContractAddress", 32));
        assert_eq!(get_type_info(&parse_quote!(felt252)), ("felt252", 32));
        assert_eq!(get_type_info(&parse_quote!(u64)), ("u64", 8));
        assert_eq!(get_type_info(&parse_quote!(bool)), ("bool", 1));
        assert_eq!(get_type_info(&parse_quote!(ByteArray)), ("ByteArray", 0));
    }
}
