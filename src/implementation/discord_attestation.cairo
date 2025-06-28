use starknet::ContractAddress;
use starknet::storage::*;
use crate::types::{AttestationSchema};

/// Discord attestation data with privacy options
#[derive(Drop, Serde, starknet::Store)]
#[allow(starknet::store_no_default_variant)]
pub enum DiscordData {
    /// Privacy-preserving attestation with hashed user ID
    Private: PrivateDiscordData,
    /// Public attestation with username included
    Public: PublicDiscordData,
}

/// Private Discord attestation data
#[derive(Drop, Serde, starknet::Store)]
pub struct PrivateDiscordData {
    /// Hash of the Discord user ID
    pub user_id_hash: felt252,
    /// Age of the Discord account in days
    pub account_age_days: u64,
    /// Timestamp when verification was performed
    pub verified_at: u64,
}

/// Public Discord attestation data
#[derive(Drop, Serde, starknet::Store)]
pub struct PublicDiscordData {
    /// Discord user ID
    pub user_id: ByteArray,
    /// Discord username at time of attestation
    pub username: ByteArray,
    /// Age of the Discord account in days
    pub account_age_days: u64,
    /// Timestamp when verification was performed
    pub verified_at: u64,
}

/// Discord-specific attestation record
#[derive(Drop, Serde, starknet::Store)]
pub struct DiscordAttestation {
    /// Unique identifier for this attestation
    pub id: felt252,
    /// Who/what is being attested to
    pub subject: ContractAddress,
    /// The Discord attestation data
    pub data: DiscordData,
    /// When the attestation was created
    pub created_at: u64,
    /// When the attestation expires (if applicable)
    pub expires_at: Option<u64>,
    /// Whether the attestation has been revoked
    pub revoked: bool,
    /// When the attestation was revoked (if applicable)
    pub revoked_at: Option<u64>,
}

/// Discord attestation interface
#[starknet::interface]
pub trait IDiscordAttestation<TContractState> {
    fn get_schema(self: @TContractState) -> AttestationSchema;
    fn get_schema_json(self: @TContractState) -> ByteArray;
    fn attest_private(
        ref self: TContractState, subject: ContractAddress, data: PrivateDiscordData,
    ) -> felt252;
    fn attest_public(
        ref self: TContractState, subject: ContractAddress, data: PublicDiscordData,
    ) -> felt252;
    fn revoke(ref self: TContractState, attestation_id: felt252);
    fn verify(self: @TContractState, attestation_id: felt252) -> bool;
    fn get_attestation(self: @TContractState, attestation_id: felt252) -> DiscordAttestation;
    fn get_subject_attestations(self: @TContractState, subject: ContractAddress) -> Array<felt252>;

    // Discord-specific functions
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::contract]
pub mod DiscordAttestationContract {
    use starknet::storage::*;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{
        AttestationSchema, DiscordAttestation, DiscordData, PrivateDiscordData,
        PublicDiscordData,
    };
    use crate::types::{FieldType, SchemaField, SchemaUtilsImpl, EnumVariant};

    #[storage]
    pub struct Storage {
        /// Contract owner who can make attestations
        owner: ContractAddress,
        /// Next attestation ID
        next_attestation_id: felt252,
        /// Mapping from attestation ID to attestation data
        attestations: Map<felt252, DiscordAttestation>,
        /// Mapping from subject to list of their attestation IDs
        subject_attestation_count: Map<ContractAddress, u32>,
        subject_attestation_at_index: Map<(ContractAddress, u32), felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AttestationCreated: AttestationCreated,
        AttestationRevoked: AttestationRevoked,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttestationCreated {
        pub attestation_id: felt252,
        pub subject: ContractAddress,
        pub created_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttestationRevoked {
        pub attestation_id: felt252,
        pub revoked_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnershipTransferred {
        pub previous_owner: ContractAddress,
        pub new_owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.next_attestation_id.write(1);
    }

    #[abi(embed_v0)]
    impl DiscordAttestationImpl of super::IDiscordAttestation<ContractState> {
        fn get_schema(self: @ContractState) -> AttestationSchema {
            // Create Private variant fields
            let mut private_fields = array![];
            private_fields.append(SchemaField {
                name: "user_id_hash",
                field_type: FieldType::Hash,
                required: true,
                size: 31, // felt252 = 31 bytes
                description: "Hash of the Discord user ID",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });
            private_fields.append(SchemaField {
                name: "account_age_days",
                field_type: FieldType::Uint64,
                required: true,
                size: 8, // 64 bits = 8 bytes
                description: "Age of the Discord account in days",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });
            private_fields.append(SchemaField {
                name: "verified_at",
                field_type: FieldType::Uint64,
                required: true,
                size: 8, // 64 bits = 8 bytes
                description: "Timestamp when verification was performed",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });

            // Create Public variant fields
            let mut public_fields = array![];
            public_fields.append(SchemaField {
                name: "user_id",
                field_type: FieldType::String,
                required: true,
                size: 0, // Variable size
                description: "Discord user ID",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });
            public_fields.append(SchemaField {
                name: "username",
                field_type: FieldType::String,
                required: true,
                size: 0, // Variable size
                description: "Discord username at time of attestation",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });
            public_fields.append(SchemaField {
                name: "account_age_days",
                field_type: FieldType::Uint64,
                required: true,
                size: 8, // 64 bits = 8 bytes
                description: "Age of the Discord account in days",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });
            public_fields.append(SchemaField {
                name: "verified_at",
                field_type: FieldType::Uint64,
                required: true,
                size: 8, // 64 bits = 8 bytes
                description: "Timestamp when verification was performed",
                enum_variants: Option::None,
                struct_definition: Option::None,
            });

            // Create enum variants
            let mut variants = array![];
            variants.append(EnumVariant {
                name: "Private",
                description: "Privacy-preserving attestation with hashed user ID",
                fields: private_fields,
            });
            variants.append(EnumVariant {
                name: "Public",
                description: "Public attestation with username included",
                fields: public_fields,
            });

            // Create the main schema with enum field
            let mut fields = array![];
            fields.append(SchemaField {
                name: "data",
                field_type: FieldType::Enum,
                required: true,
                size: 0, // Variable size enum
                description: "Discord attestation data with privacy options",
                enum_variants: Option::Some(variants),
                struct_definition: Option::None,
            });

            AttestationSchema {
                name: "Discord Account Verification",
                description: "Attests to the ownership and age of a Discord account",
                version: 1,
                fields,
            }
        }

        fn get_schema_json(self: @ContractState) -> ByteArray {
            let schema = self.get_schema();
            SchemaUtilsImpl::schema_to_json(schema)
        }

        fn attest_private(
            ref self: ContractState, subject: ContractAddress, data: PrivateDiscordData,
        ) -> felt252 {
            // Only owner can make attestations
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can attest');

            let attestation_id = self.next_attestation_id.read();
            let created_at = get_block_timestamp();

            // Calculate expiration (1 year from now)
            let expires_at = Option::Some(created_at + 31536000);

            let attestation = DiscordAttestation {
                id: attestation_id,
                subject,
                data: DiscordData::Private(data),
                created_at,
                expires_at,
                revoked: false,
                revoked_at: Option::None,
            };

            // Store the attestation
            self.attestations.entry(attestation_id).write(attestation);

            // Add to subject's attestation list
            let count = self.subject_attestation_count.entry(subject).read();
            self.subject_attestation_at_index.entry((subject, count)).write(attestation_id);
            self.subject_attestation_count.entry(subject).write(count + 1);

            // Increment next ID
            self.next_attestation_id.write(attestation_id + 1);

            // Emit event
            self
                .emit(
                    Event::AttestationCreated(
                        AttestationCreated { attestation_id, subject, created_at },
                    ),
                );

            attestation_id
        }

        fn attest_public(
            ref self: ContractState, subject: ContractAddress, data: PublicDiscordData,
        ) -> felt252 {
            // Only owner can make attestations
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can attest');

            let attestation_id = self.next_attestation_id.read();
            let created_at = get_block_timestamp();

            // Calculate expiration (1 year from now)
            let expires_at = Option::Some(created_at + 31536000);

            let attestation = DiscordAttestation {
                id: attestation_id,
                subject,
                data: DiscordData::Public(data),
                created_at,
                expires_at,
                revoked: false,
                revoked_at: Option::None,
            };

            // Store the attestation
            self.attestations.entry(attestation_id).write(attestation);

            // Add to subject's attestation list
            let count = self.subject_attestation_count.entry(subject).read();
            self.subject_attestation_at_index.entry((subject, count)).write(attestation_id);
            self.subject_attestation_count.entry(subject).write(count + 1);

            // Increment next ID
            self.next_attestation_id.write(attestation_id + 1);

            // Emit event
            self
                .emit(
                    Event::AttestationCreated(
                        AttestationCreated { attestation_id, subject, created_at },
                    ),
                );

            attestation_id
        }

        fn revoke(ref self: ContractState, attestation_id: felt252) {
            // Only owner can revoke attestations
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can revoke');

            let mut attestation = self.attestations.entry(attestation_id).read();
            assert(!attestation.revoked, 'Already revoked');

            let revoked_at = get_block_timestamp();
            attestation.revoked = true;
            attestation.revoked_at = Option::Some(revoked_at);

            self.attestations.entry(attestation_id).write(attestation);

            self.emit(Event::AttestationRevoked(AttestationRevoked { attestation_id, revoked_at }));
        }

        fn verify(self: @ContractState, attestation_id: felt252) -> bool {
            let attestation = self.attestations.entry(attestation_id).read();

            // Check if attestation exists (id should be > 0)
            if attestation.id == 0 {
                return false;
            }

            // Check if revoked
            if attestation.revoked {
                return false;
            }

            // Check if expired
            match attestation.expires_at {
                Option::Some(expires_at) => {
                    let current_time = get_block_timestamp();
                    if current_time > expires_at {
                        return false;
                    }
                },
                Option::None => {},
            }

            true
        }

        fn get_attestation(self: @ContractState, attestation_id: felt252) -> DiscordAttestation {
            self.attestations.entry(attestation_id).read()
        }

        fn get_subject_attestations(self: @ContractState, subject: ContractAddress) -> Array<felt252> {
            let mut result = array![];
            let count = self.subject_attestation_count.entry(subject).read();

            let mut i = 0;
            while i < count {
                let attestation_id = self.subject_attestation_at_index.entry((subject, i)).read();
                result.append(attestation_id);
                i += 1;
            }

            result
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let caller = get_caller_address();
            let current_owner = self.owner.read();
            assert(caller == current_owner, 'Only owner can transfer');

            self.owner.write(new_owner);

            self
                .emit(
                    Event::OwnershipTransferred(
                        OwnershipTransferred { previous_owner: current_owner, new_owner },
                    ),
                );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        PrivateDiscordData, PublicDiscordData, DiscordData
    };
    use crate::types::FieldType;

    #[test]
    fn test_private_discord_data_creation() {
        let private_data = PrivateDiscordData {
            user_id_hash: 0x123456789abcdef,
            account_age_days: 365,
            verified_at: 1000,
        };

        assert(private_data.user_id_hash == 0x123456789abcdef, 'Wrong user_id_hash');
        assert(private_data.account_age_days == 365, 'Wrong account_age_days');
        assert(private_data.verified_at == 1000, 'Wrong verified_at');
    }

    #[test]
    fn test_public_discord_data_creation() {
        let public_data = PublicDiscordData {
            user_id: "123456789",
            username: "testuser#1234",
            account_age_days: 730,
            verified_at: 2000,
        };

        assert(public_data.user_id == "123456789", 'Wrong user_id');
        assert(public_data.username == "testuser#1234", 'Wrong username');
        assert(public_data.account_age_days == 730, 'Wrong account_age_days');
        assert(public_data.verified_at == 2000, 'Wrong verified_at');
    }

    #[test]
    fn test_discord_data_enum_private() {
        let private_data = PrivateDiscordData {
            user_id_hash: 0x123,
            account_age_days: 100,
            verified_at: 1000,
        };

        let discord_data = DiscordData::Private(private_data);

        match discord_data {
            DiscordData::Private(data) => {
                assert(data.user_id_hash == 0x123, 'Wrong hash in enum');
                assert(data.account_age_days == 100, 'Wrong age in enum');
            },
            DiscordData::Public(_) => panic!("Should be private variant")
        }
    }

    #[test]
    fn test_discord_data_enum_public() {
        let public_data = PublicDiscordData {
            user_id: "test123",
            username: "testuser",
            account_age_days: 200,
            verified_at: 2000,
        };

        let discord_data = DiscordData::Public(public_data);

        match discord_data {
            DiscordData::Public(data) => {
                assert(data.user_id == "test123", 'Wrong user_id in enum');
                assert(data.username == "testuser", 'Wrong username in enum');
                assert(data.account_age_days == 200, 'Wrong age in enum');
            },
            DiscordData::Private(_) => panic!("Should be public variant")
        }
    }


    #[test]
    fn test_zero_values() {
        let private_data = PrivateDiscordData {
            user_id_hash: 0,
            account_age_days: 0,
            verified_at: 0,
        };

        assert(private_data.user_id_hash == 0, 'Zero hash should work');
        assert(private_data.account_age_days == 0, 'Zero age should work');
        assert(private_data.verified_at == 0, 'Zero timestamp should work');
    }

    #[test]
    fn test_max_values() {
        let max_hash = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        let max_u64 = 18446744073709551615_u64;

        let private_data = PrivateDiscordData {
            user_id_hash: max_hash,
            account_age_days: max_u64,
            verified_at: max_u64,
        };

        assert(private_data.user_id_hash == max_hash, 'Max hash should work');
        assert(private_data.account_age_days == max_u64, 'Max age should work');
        assert(private_data.verified_at == max_u64, 'Max timestamp should work');
    }

    #[test]
    fn test_empty_strings() {
        let public_data = PublicDiscordData {
            user_id: "",
            username: "",
            account_age_days: 100,
            verified_at: 1000,
        };

        assert(public_data.user_id == "", 'Empty user_id should work');
        assert(public_data.username == "", 'Empty username should work');
    }

    #[test]
    fn test_long_strings() {
        let public_data = PublicDiscordData {
            user_id: "very_long_user_id_12345",
            username: "long_username#9999",
            account_age_days: 500,
            verified_at: 3000,
        };

        assert(public_data.user_id == "very_long_user_id_12345", 'Long user_id works');
        assert(public_data.username == "long_username#9999", 'Long username works');
    }

    #[test]
    fn test_enum_field_type_exists() {
        let enum_type = FieldType::Enum;
        match enum_type {
            FieldType::Enum => assert(true, 'Enum field type exists'),
            _ => panic!("Should be Enum type")
        }
    }
}
