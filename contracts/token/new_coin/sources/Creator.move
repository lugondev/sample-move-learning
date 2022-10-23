module CreatorToken::token04 {
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::string;

    use aptos_std::type_info;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability, FreezeCapability};

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    const UT_ERR: u64 = 1;

    const ECOIN_EXISTS: u64 = 2;
    const ECOIN_INFO_ADDRESS_MISMATCH: u64 = 3;
    const ECOIN_STORE_ALREADY_PUBLISHED: u64 = 4;

    const MONITOR_SUPPLY: bool = true;

    struct LUS has key {}

    struct LUG has key {}

    struct Capabilities<phantom CoinType> has key {
        burn_cap: Option<BurnCapability<CoinType>>,
        freeze_cap: Option<FreezeCapability<CoinType>>,
        mint_cap: Option<MintCapability<CoinType>>,
    }

    public entry fun create<CoinType>(
        source: &signer,
        name: string::String,
        symbol: string::String,
        decimals: u8,
        max_supply: u64
    ) {
        assert!(!exists<Capabilities<CoinType>>(address_of(source)), ECOIN_EXISTS);

        let (cap_burn, cap_freeze, cap_mint) = coin::initialize<CoinType>(
            source,
            name,
            symbol,
            decimals,
            MONITOR_SUPPLY
        );

        coin::register<CoinType>(source);
        let minted = coin::mint<CoinType>(max_supply, &cap_mint);

        coin::deposit(address_of(source), minted);

        move_to(source, Capabilities<CoinType> {
            burn_cap: option::some(cap_burn),
            freeze_cap: option::some(cap_freeze),
            mint_cap: option::some(cap_mint),
        });
    }

    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    public entry fun register<CoinType>(account: &signer) {
        coin::register<CoinType>(account);
    }

    #[test]
    fun mint_new_tokens() {
        let root = create_account_for_test(@0xC0FFEE);
        let user = create_account_for_test(@0x123456);

        create<LUS>(&root, string::utf8(b"LugonSample"), string::utf8(b"LUS"), 8, 100000000000000000);
        coin::register<LUS>(&user);
        assert!(coin::balance<LUS>(address_of(&root)) == 100000000000000000, UT_ERR);
        assert!(coin::balance<LUS>(address_of(&user)) == 0, UT_ERR);
        coin::transfer<LUS>(&root, address_of(&user), 100 ^ 8);
        assert!(coin::balance<LUS>(address_of(&user)) == 100 ^ 8, UT_ERR);

        // register<LUS>(&user);
        // create<LUS>(&user, string::utf8(b"LugonSample"), string::utf8(b"LUG"), 8, 100000000000000000);
        // coin::register<LUS>(&user);
        // coin::transfer<LUS>(&user, address_of(&root), 100 ^ 8);
        // assert!(coin::balance<LUS>(address_of(&user)) == 0, UT_ERR);
        //
        // create<LUG>(&user, string::utf8(b"LugonSample"), string::utf8(b"LUG"), 8, 100000000000000000);
        // coin::register<LUG>(&user);
        // assert!(coin::balance<LUG>(address_of(&user)) == 0, UT_ERR);
    }
}
