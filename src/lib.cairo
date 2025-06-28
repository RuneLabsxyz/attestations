mod implementation;
mod interfaces;
mod types;
pub use implementation::{
    DiscordAttestation, DiscordData, IDiscordAttestation, PrivateDiscordData, PublicDiscordData,
};
pub use interfaces::IAttestation;

pub use types::{
    Attestation, AttestationSchema, EnumVariant, FieldType, SchemaField, SchemaUtils, StructDefinition,
};
