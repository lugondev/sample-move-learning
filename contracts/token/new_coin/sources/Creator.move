module CreatorToken::token05 {
    use std::signer::address_of;
    use std::string;

    use aptos_std::type_info;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;

    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    const UT_ERR: u64 = 1;

    const ECOIN_EXISTS: u64 = 2;
    const ECOIN_INFO_ADDRESS_MISMATCH: u64 = 3;
    const ECOIN_STORE_ALREADY_PUBLISHED: u64 = 4;

    const MONITOR_SUPPLY: bool = false;

    struct LUS has key {}

    // struct Capabilities<phantom CoinType> has key {
    //     burn_cap: BurnCapability<CoinType>,
    //     freeze_cap: FreezeCapability<CoinType>,
    //     mint_cap: MintCapability<CoinType>,
    // }

    public entry fun create< CoinType>(
        source: &signer,
        name: string::String,
        symbol: string::String,
        decimals: u8,
        max_supply: u64
    ) {
        managed_coin::initialize<CoinType>(
            source,
            *string::bytes(&name),
            *string::bytes(&symbol),
            decimals,
            MONITOR_SUPPLY
        );

        coin::initialize<>()

        if (!coin::is_account_registered<CoinType>(address_of(source))) {
            coin::register<CoinType>(source);
        };

        managed_coin::mint<CoinType>(source, address_of(source), max_supply);
        // coin::deposit(address_of(source), minted);

        // move_to(source, Capabilities<CoinType> {
        //     burn_cap: cap_burn,
        //     freeze_cap: cap_freeze,
        //     mint_cap: cap_mint,
        // });
    }

    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    public fun register<CoinType>(account: &signer) {
        let account_addr = address_of(account);
        if (!coin::is_account_registered<CoinType>(account_addr)) {
            coin::register<CoinType>(account);
        };
    }

    #[test]
    fun mint_new_tokens() {
        let root = create_account_for_test(@0xC0FFEE);

        coin::register<LUS>(&root);
        create<LUS>(&root, string::utf8(b"LugonSample"), string::utf8(b"LUS"), 8, 100000000000000000);
        let user = create_account_for_test(@0x123456);
        coin::register<LUS>(&user);
        assert!(coin::balance<LUS>(address_of(&root)) == 100000000000000000, UT_ERR);
        assert!(coin::balance<LUS>(address_of(&user)) == 0, UT_ERR);
        coin::transfer<LUS>(&root, address_of(&user), 100 ^ 8);
        let balanceOfUser = coin::balance<LUS>(address_of(&user));
        assert!(balanceOfUser == 100 ^ 8, UT_ERR);

        debug::print(&balanceOfUser);

        managed_coin::burn<LUS>(&root, 100);
        managed_coin::mint<LUS>(&root, address_of(&root), 100000000000000000);
    }
}
