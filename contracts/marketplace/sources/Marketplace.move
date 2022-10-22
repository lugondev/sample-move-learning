module MarketAddress::marketplace01 {
    use std::signer;
    use std::string::String;
    use std::error;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_token::token::{Self, Token, TokenId, deposit_token, withdraw_token, merge, split};
    //
    // Errors.
    //


    /// Not admin of market
    const ENOT_ADMIN: u64 = 1;

    /// Token already listed
    const ETOKEN_ALREADY_LISTED: u64 = 2;

    /// Token listing no longer exists
    const ETOKEN_LISTING_NOT_EXIST: u64 = 3;

    /// Token is not in escrow
    const ETOKEN_NOT_IN_ESCROW: u64 = 4;

    /// Token cannot be moved out of escrow before the lockup time
    const ETOKEN_CANNOT_MOVE_OUT_OF_ESCROW_BEFORE_LOCKUP_TIME: u64 = 5;

    /// Token buy amount doesn't match listing amount
    const ETOKEN_AMOUNT_NOT_MATCH: u64 = 6;

    /// Not enough coin to buy token
    const ENOT_ENOUGH_COIN: u64 = 7;

    /// Coin is not in whitelist
    const ECOIN_NOT_IN_WHITELIST: u64 = 8;

    // Market Config
    struct Market has key {
        admin_address: address,
        fee_recipient: address,
        fee_percentage: u64, // %
        handle_royalty: bool,
        create_sale_events: EventHandle<SaleCreatedEvent>,
        cancel_sale_events: EventHandle<SaleCancelledEvent>,
        sale_completed_events: EventHandle<SaleCompletedEvent>,
        price_updated_events: EventHandle<PriceUpdatedEvent>,
        coin_whitelist: Table<TypeInfo, bool>,
    }

    /// TokenCoinSwap records a swap ask for swapping token_amount with CoinType with a minimal price per token
    struct TokenCoinSwap<phantom CoinType> has store, drop {
        token_amount: u64,
        price_per_token: u64,
    }

    /// The listing of all tokens for swapping stored at token owner's account
    struct TokenListings<phantom CoinType> has key {
        // key is the token id for swapping and value is the min price of target coin type.
        listings: Table<TokenId, TokenCoinSwap<CoinType>>,
    }

    /// TokenEscrow holds the tokens that cannot be withdrawn or transferred
    struct TokenEscrow has store {
        token: Token,
        // until the locked time runs out, the owner cannot move the token out of the escrow
        // the default value is 0 meaning the owner can move the coin out anytime
        locked_until_secs: u64,
    }

    /// TokenStoreEscrow holds a map of token id to their tokenEscrow
    struct TokenStoreEscrow has key {
        token_escrows: Table<TokenId, TokenEscrow>,
    }

    struct SaleCreatedEvent has drop, store {
        token_id: TokenId,
        token_seller: address,
        amount: u64,
        price: u64,
        locked_until_secs: u64,
        coin_type_info: TypeInfo,
        timestamp: u64
    }

    struct SaleCancelledEvent has drop, store {
        token_id: TokenId,
        token_seller: address,
        amount: u64,
        coin_type_info: TypeInfo,
        timestamp: u64
    }

    struct SaleCompletedEvent has drop, store {
        token_id: TokenId,
        token_seller: address,
        token_buyer: address,
        amount: u64,
        coin_amount: u64,
        coin_type_info: TypeInfo,
        timestamp: u64
    }

    struct PriceUpdatedEvent has drop, store {
        token_id: TokenId,
        token_seller: address,
        amount: u64,
        new_price_per_token: u64,
        coin_type_info: TypeInfo,
        timestamp: u64
    }

    public entry fun initialize_market (
        sender: &signer,
        admin_address: address,
        fee_recipient: address,
        fee_percentage: u64,
        handle_royalty: bool
    ) {
        assert!(signer::address_of(sender) == @MarketAddress, ENOT_ADMIN);
        assert!(!exists<Market>(@MarketAddress), ENOT_ADMIN);
        move_to(sender, Market {
            admin_address,
            fee_recipient,
            fee_percentage,
            handle_royalty,
            create_sale_events: account::new_event_handle<SaleCreatedEvent>(sender),
            cancel_sale_events: account::new_event_handle<SaleCancelledEvent>(sender),
            sale_completed_events: account::new_event_handle<SaleCompletedEvent>(sender),
            price_updated_events: account::new_event_handle<PriceUpdatedEvent>(sender),
            coin_whitelist: table::new<TypeInfo, bool>()
        });
    }

    public entry fun add_coin_type_to_whitelist<CoinType>(sender: &signer) acquires Market {
        let market = borrow_global_mut<Market>(@MarketAddress);
        assert!(signer::address_of(sender) == market.admin_address, error::permission_denied(ENOT_ADMIN));
        table::add(&mut market.coin_whitelist, type_info::type_of<CoinType>(), true);
    }

    public entry fun remove_coin_type_from_whitelist<CoinType>(sender: &signer) acquires Market {
        let market = borrow_global_mut<Market>(@MarketAddress);
        assert!(signer::address_of(sender) == market.admin_address, error::permission_denied(ENOT_ADMIN));
        let coin_type_info = type_info::type_of<CoinType>();
        assert!(table::contains(& market.coin_whitelist, coin_type_info), error::not_found(ETOKEN_LISTING_NOT_EXIST));
        table::remove(&mut market.coin_whitelist, coin_type_info);
    }

    public entry fun set_admin_address (
        sender: &signer,
        admin_address: address,
    ) acquires Market {
        let market = borrow_global_mut<Market>(@MarketAddress);
        assert!(signer::address_of(sender) == market.admin_address, error::permission_denied(ENOT_ADMIN));
        market.admin_address = admin_address;
    }

    public entry fun set_fee_recipient (
        sender: &signer,
        fee_recipient: address,
    ) acquires Market {
        let market = borrow_global_mut<Market>(@MarketAddress);
        assert!(signer::address_of(sender) == market.admin_address, error::permission_denied(ENOT_ADMIN));
        market.fee_recipient = fee_recipient;
    }

    public entry fun set_fee_percentage (
        sender: &signer,
        fee_percentage: u64,
    ) acquires Market {
        let market = borrow_global_mut<Market>(@MarketAddress);
        assert!(signer::address_of(sender) == market.admin_address, error::permission_denied(ENOT_ADMIN));
        market.fee_percentage = fee_percentage;
    }

    public entry fun set_handle_royalty (
        sender: &signer,
        handle_royalty: bool,
    ) acquires Market {
        let market = borrow_global_mut<Market>(@MarketAddress);
        assert!(signer::address_of(sender) == market.admin_address, ENOT_ADMIN);
        market.handle_royalty = handle_royalty;
    }

    /// Token owner lists their token for swapping
    public entry fun create_sale<CoinType>(
        token_seller: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        price_per_token: u64,
        locked_until_secs: u64
    ) acquires Market, TokenStoreEscrow, TokenListings {
        let market = borrow_global_mut<Market>(@MarketAddress);
        let coin_type_info = type_info::type_of<CoinType>();
        assert!(table::contains(& market.coin_whitelist, coin_type_info), error::not_found(ECOIN_NOT_IN_WHITELIST));
        assert!(*table::borrow(& market.coin_whitelist, coin_type_info) == true, error::not_found(ECOIN_NOT_IN_WHITELIST));

        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        initialize_token_store_escrow(token_seller);
        // withdraw the token and store them to the token_seller's TokenEscrow
        let token = withdraw_token(token_seller, token_id, token_amount);
        deposit_token_to_escrow(token_seller, token_id, token, locked_until_secs);
        // add the exchange info TokenCoinSwap list
        initialize_token_listing<CoinType>(token_seller);
        let swap = TokenCoinSwap<CoinType> {
            token_amount,
            price_per_token,
        };
        let listing = &mut borrow_global_mut<TokenListings<CoinType>>(signer::address_of(token_seller)).listings;
        assert!(!table::contains(listing, token_id), error::already_exists(ETOKEN_ALREADY_LISTED));
        table::add(listing, token_id, swap);

        event::emit_event<SaleCreatedEvent>(
            &mut market.create_sale_events,
            SaleCreatedEvent {
                token_id,
                token_seller: signer::address_of(token_seller),
                amount: token_amount,
                price: price_per_token,
                locked_until_secs,
                coin_type_info,
                timestamp: timestamp::now_microseconds()
            },
        );
    }

    // Update price
    public entry fun edit_price<CoinType>(
        token_seller: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        price_per_token: u64
    ) acquires Market, TokenListings {
        let token_seller_addr = signer::address_of(token_seller);
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let token_listing = borrow_global_mut<TokenListings<CoinType>>(token_seller_addr);
        assert!(table::contains(&token_listing.listings, token_id), error::not_found(ETOKEN_LISTING_NOT_EXIST));

        let token_swap = table::borrow_mut(&mut token_listing.listings, token_id);
        token_swap.price_per_token = price_per_token;

        let market = borrow_global_mut<Market>(@MarketAddress);
        event::emit_event<PriceUpdatedEvent>(
            &mut market.price_updated_events,
            PriceUpdatedEvent {
                token_id,
                token_seller: token_seller_addr,
                amount: token_swap.token_amount,
                new_price_per_token: price_per_token,
                coin_type_info: type_info::type_of<CoinType>(),
                timestamp: timestamp::now_microseconds()
            },
        );
    }

    /// Cancel token listing
    public entry fun cancel_sale<CoinType> (
        token_seller: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
    ) acquires Market, TokenListings, TokenStoreEscrow {
        let token_seller_addr = signer::address_of(token_seller);
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let listing = &mut borrow_global_mut<TokenListings<CoinType>>(token_seller_addr).listings;
        // remove the listing entry
        assert!(table::contains(listing, token_id), error::not_found(ETOKEN_LISTING_NOT_EXIST));
        let token_amount = table::borrow(listing, token_id).token_amount;
        table::remove(listing, token_id);
        // get token out of escrow and deposit back to owner token store
        let tokens = withdraw_token_from_escrow(token_seller, token_id, token_amount);
        deposit_token(token_seller, tokens);

        let event_handle = &mut borrow_global_mut<Market>(@MarketAddress).cancel_sale_events;
        event::emit_event<SaleCancelledEvent>(
            event_handle,
            SaleCancelledEvent {
                token_id,
                token_seller: token_seller_addr,
                amount: token_amount,
                coin_type_info: type_info::type_of<CoinType>(),
                timestamp: timestamp::now_microseconds()
            },
        );
    }

    /// Coin owner withdraw coin to swap with tokens listed for swapping at the token owner's address.
    public entry fun make_order<CoinType>(
        token_buyer: &signer,
        token_seller: address,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
    ) acquires Market, TokenListings, TokenStoreEscrow {
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        // valide listing existing and coin owner has sufficient balance
        let token_buyer_address = signer::address_of(token_buyer);
        let token_listing = borrow_global_mut<TokenListings<CoinType>>(token_seller);
        assert!(table::contains(&token_listing.listings, token_id), error::not_found(ETOKEN_LISTING_NOT_EXIST));
        // validate min price and amount
        let token_swap = table::borrow_mut(&mut token_listing.listings, token_id);
        let coin_amount = token_swap.price_per_token * token_amount;
        assert!(coin::balance<CoinType>(token_buyer_address) >= coin_amount, error::invalid_argument(ENOT_ENOUGH_COIN));
        assert!(token_swap.token_amount >= token_amount, error::invalid_argument(ETOKEN_AMOUNT_NOT_MATCH));

        // withdraw from token escrow of tokens
        let tokens = withdraw_token_from_escrow_internal(token_seller, token_id, token_amount);

        // deposit tokens to the token_buyer
        deposit_token(token_buyer, tokens);

        // handle the fee
        let fee_percentage = borrow_global<Market>(@MarketAddress).fee_percentage;

        let royalty = token::get_royalty(token_id);

        let total_cost = token_swap.price_per_token * token_amount;

        let market_fee = total_cost * fee_percentage / 100;

        let remaining = total_cost - market_fee;

        let royalty_denominator = token::get_royalty_denominator(&royalty);
        let handle_royalty = borrow_global<Market>(@MarketAddress).handle_royalty;
        let royalty_fee = if (royalty_denominator == 0 || handle_royalty) {
            0
        } else {
            remaining * token::get_royalty_numerator(&royalty) / token::get_royalty_denominator(&royalty)
        };

        // deposit to the original creators
        let royalty_payee = token::get_royalty_payee(&royalty);
        let coin = coin::withdraw<CoinType>(token_buyer, royalty_fee);
        coin::deposit(royalty_payee, coin);

        // deposit coin to the token_seller
        let coin = coin::withdraw<CoinType>(token_buyer, remaining - royalty_fee);
        coin::deposit(token_seller, coin);

        // deposit coin to the admin of market
        let fee_recipient = borrow_global<Market>(@MarketAddress).fee_recipient;
        let coin = coin::withdraw<CoinType>(token_buyer, market_fee);
        coin::deposit(fee_recipient, coin);

        // update the token listing
        if (token_swap.token_amount == token_amount) {
            // delete the entry in the token listing
            table::remove(&mut token_listing.listings, token_id);
        } else {
            token_swap.token_amount = token_swap.token_amount - token_amount;
        };

        let market = borrow_global_mut<Market>(@MarketAddress);
        event::emit_event<SaleCompletedEvent>(
            &mut market.sale_completed_events,
            SaleCompletedEvent {
                token_id,
                token_seller,
                token_buyer: token_buyer_address,
                amount: token_amount,
                coin_amount: total_cost,
                coin_type_info: type_info::type_of<CoinType>(),
                timestamp: timestamp::now_microseconds()
            },
        );
    }

    public fun does_listing_exist<CoinType>(
        token_seller: address,
        token_id: TokenId
    ): bool acquires TokenListings {
        let token_listing = borrow_global<TokenListings<CoinType>>(token_seller);
        table::contains(&token_listing.listings, token_id)
    }

    /// Initalize the token listing for a token owner
    fun initialize_token_listing<CoinType>(token_seller: &signer) {
        let addr = signer::address_of(token_seller);
        if (!exists<TokenListings<CoinType>>(addr)) {
            let token_listing = TokenListings<CoinType> {
                listings: table::new<TokenId, TokenCoinSwap<CoinType>>()
            };
            move_to(token_seller, token_listing);
        }
    }

    /// Intialize the token escrow
    fun initialize_token_store_escrow(token_seller: &signer) {
        let addr = signer::address_of(token_seller);
        if (!exists<TokenStoreEscrow>(addr)) {
            let token_store_escrow = TokenStoreEscrow {
                token_escrows: table::new<TokenId, TokenEscrow>()
            };
            move_to(token_seller, token_store_escrow);
        }
    }

    /// Put the token into escrow that cannot be transferred or withdrawed by the owner.
    public fun deposit_token_to_escrow(
        token_seller: &signer,
        token_id: TokenId,
        tokens: Token,
        locked_until_secs: u64
    ) acquires TokenStoreEscrow {
        let tokens_in_escrow = &mut borrow_global_mut<TokenStoreEscrow>(
            signer::address_of(token_seller)).token_escrows;
        if (table::contains(tokens_in_escrow, token_id)) {
            let dst = &mut table::borrow_mut(tokens_in_escrow, token_id).token;
            merge(dst, tokens);
        } else {
            let token_escrow = TokenEscrow {
                token: tokens,
                locked_until_secs
            };
            table::add(tokens_in_escrow, token_id, token_escrow);
        };
    }

    /// Private function for withdraw tokens from an escrow stored in token owner address
    fun withdraw_token_from_escrow_internal(
        token_seller_addr: address,
        token_id: TokenId,
        amount: u64
    ): Token acquires TokenStoreEscrow {
        let tokens_in_escrow = &mut borrow_global_mut<TokenStoreEscrow>(token_seller_addr).token_escrows;
        assert!(table::contains(tokens_in_escrow, token_id), error::not_found(ETOKEN_NOT_IN_ESCROW));
        let token_escrow = table::borrow_mut(tokens_in_escrow, token_id);
        if (amount == token::get_token_amount(&token_escrow.token)) {
            // destruct the token escrow to reclaim storage
            let TokenEscrow {
                token: tokens,
                locked_until_secs: _
            } = table::remove(tokens_in_escrow, token_id);
            tokens
        } else {
            split(&mut token_escrow.token, amount)
        }
    }

    /// Withdraw tokens from the token escrow. It needs a signer to authorize
    public fun withdraw_token_from_escrow(
        token_seller: &signer,
        token_id: TokenId,
        amount: u64
    ): Token acquires TokenStoreEscrow {
        let tokens_in_escrow = &mut borrow_global_mut<TokenStoreEscrow>(signer::address_of(token_seller)).token_escrows;
        assert!(table::contains(tokens_in_escrow, token_id), error::not_found(ETOKEN_NOT_IN_ESCROW));
        let token_escrow = table::borrow_mut(tokens_in_escrow, token_id);
        assert!(timestamp::now_seconds() > token_escrow.locked_until_secs, error::invalid_argument(ETOKEN_CANNOT_MOVE_OUT_OF_ESCROW_BEFORE_LOCKUP_TIME));
        withdraw_token_from_escrow_internal(signer::address_of(token_seller), token_id, amount)
    }

    #[test(dev = @MarketAddress, receiver = @0xCAFE)]
    public entry fun test_initialize_and_config_market(
        dev: &signer,
        receiver: &signer,
    ) acquires Market {
        account::create_account_for_test(signer::address_of(dev));
        account::create_account_for_test(signer::address_of(receiver));
        initialize_market(dev, signer::address_of(dev), signer::address_of(receiver), 10, false);

        let market = borrow_global<Market>(@MarketAddress);
        assert!(market.admin_address == signer::address_of(dev), 1);
        assert!(market.fee_recipient == signer::address_of(receiver), 1);
        assert!(market.fee_percentage == 10, 1);
        assert!(!market.handle_royalty, 1);
        set_admin_address(dev, signer::address_of(receiver));
        set_fee_recipient(receiver, signer::address_of(dev));
        set_fee_percentage(receiver, 20);
        set_handle_royalty(receiver, true);
        let market = borrow_global<Market>(@MarketAddress);
        assert!(market.admin_address == signer::address_of(receiver), 1);
        assert!(market.fee_recipient == signer::address_of(dev), 1);
        assert!(market.fee_percentage == 20, 1);
        assert!(market.handle_royalty, 1);
    }

    #[test(dev = @MarketAddress, token_seller = @0xAB, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 393224)]
    public entry fun test_coin_in_whitelist(
        dev: &signer,
        token_seller: &signer,
        aptos_framework: &signer
    ) acquires Market, TokenListings, TokenStoreEscrow {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        account::create_account_for_test(signer::address_of(dev));
        account::create_account_for_test(signer::address_of(token_seller));
        initialize_market(dev, signer::address_of(dev), signer::address_of(dev), 10, false);
        let _ = token::create_collection_and_token(
            token_seller,
            100,
            100,
            100,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );
        add_coin_type_to_whitelist<coin::FakeMoney>(dev);
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            50,
            1,
            0
        );
        remove_coin_type_from_whitelist<coin::FakeMoney>(dev);
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            50,
            1,
            0
        );
    }

    #[test(dev = @MarketAddress, receiver = @0xCAFE, token_seller = @0xAB, token_buyer = @0x1, aptos_framework = @aptos_framework)]
    public entry fun test_make_order_and_relist(
        dev: &signer,
        receiver: &signer,
        token_seller: &signer,
        token_buyer: &signer,
        aptos_framework: &signer
    ) acquires Market, TokenStoreEscrow, TokenListings {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        account::create_account_for_test(signer::address_of(dev));
        account::create_account_for_test(signer::address_of(receiver));

        initialize_market(dev, signer::address_of(dev), signer::address_of(receiver), 10, false);
        account::create_account_for_test(signer::address_of(token_seller));

        let token_id = token::create_collection_and_token(
            token_seller,
            100,
            100,
            100,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );
        account::create_account_for_test(signer::address_of(token_buyer));
        token::initialize_token_store(token_buyer);
        coin::create_fake_money(token_buyer, token_seller, 100);
        coin::register<coin::FakeMoney>(receiver);
        add_coin_type_to_whitelist<coin::FakeMoney>(dev);
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            100,
            1,
            0
        );
        make_order<coin::FakeMoney>(
            token_buyer,
            signer::address_of(token_seller),
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            50,
        );
        // coin owner only has 50 coins left
        assert!(coin::balance<coin::FakeMoney>(signer::address_of(token_buyer)) == 50, 1);
        assert!(coin::balance<coin::FakeMoney>(signer::address_of(token_seller)) == 45, 1);
        assert!(coin::balance<coin::FakeMoney>(signer::address_of(receiver)) == 5, 1);
        // all tokens in token escrow or transferred. Token owner has 0 token in token_store
        assert!(token::balance_of(signer::address_of(token_seller), token_id) == 0, 1);

        let token_listing = &borrow_global<TokenListings<coin::FakeMoney>>(signer::address_of(token_seller)).listings;

        let token_coin_swap = table::borrow(token_listing, token_id);
        // sold 50 token only 50 tokens left
        assert!(token_coin_swap.token_amount == 50, token_coin_swap.token_amount);

        // token owner cancel listing of remaining tokens
        cancel_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
        );

        // token owner relist 10 tokens with a different locktime
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            10,
            1,
            20000000
        );

        make_order<coin::FakeMoney>(
            token_buyer,
            signer::address_of(token_seller),
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            10,
        );

        // expect buyer can buy the token at anytime
        assert!(token::balance_of(signer::address_of(token_seller), token_id) == 40, 1);
        assert!(coin::balance<coin::FakeMoney>(signer::address_of(token_buyer)) == 40, coin::balance<coin::FakeMoney>(signer::address_of(token_buyer)));
    }

    #[test(dev = @MarketAddress, token_seller = @0xAB, token_buyer = @0x1, aptos_framework = @aptos_framework)]
    public entry fun test_update_price(
        dev: &signer,
        token_seller: &signer,
        token_buyer: &signer,
        aptos_framework: &signer
    ) acquires Market, TokenStoreEscrow, TokenListings {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        account::create_account_for_test(signer::address_of(dev));

        initialize_market(dev, signer::address_of(dev), signer::address_of(dev), 10, false);
        account::create_account_for_test(signer::address_of(token_seller));

        let token_id = token::create_collection_and_token(
            token_seller,
            100,
            100,
            100,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );
        account::create_account_for_test(signer::address_of(token_buyer));
        token::initialize_token_store(token_buyer);
        coin::create_fake_money(token_buyer, token_seller, 100);
        coin::register<coin::FakeMoney>(dev);
        add_coin_type_to_whitelist<coin::FakeMoney>(dev);
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            100,
            1,
            0
        );

        edit_price<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            2
        );

        make_order<coin::FakeMoney>(
            token_buyer,
            signer::address_of(token_seller),
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            50,
        );

        // buyer out of cash
        assert!(token::balance_of(signer::address_of(token_seller), token_id) == 0, 1);
        assert!(coin::balance<coin::FakeMoney>(signer::address_of(token_buyer)) == 0, coin::balance<coin::FakeMoney>(signer::address_of(token_buyer)));

    }

    #[test(dev = @MarketAddress, token_seller = @0xAB, token_buyer = @0x1, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65541)]
    public fun test_escrow_lock_time(
        dev: &signer,
        token_seller: &signer,
        token_buyer: &signer,
        aptos_framework: &signer
    ) acquires Market, TokenStoreEscrow, TokenListings {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        account::create_account_for_test(signer::address_of(dev));
        initialize_market(dev, signer::address_of(dev), signer::address_of(dev), 0, false);
        account::create_account_for_test(signer::address_of(token_seller));
        let token_id = token::create_collection_and_token(
            token_seller,
            100,
            100,
            100,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );
        account::create_account_for_test(signer::address_of(token_buyer));
        token::initialize_token_store(token_buyer);
        coin::create_fake_money(token_buyer, token_seller, 100);
        add_coin_type_to_whitelist<coin::FakeMoney>(dev);
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            100,
            1,
            20000000,
        );
        timestamp::update_global_time_for_test(15000000);
        let token = withdraw_token_from_escrow(token_seller, token_id, 1);
        deposit_token(token_seller, token);
    }

    #[test(dev = @MarketAddress, token_seller = @0xAB, token_buyer = @0x1, aptos_framework = @aptos_framework)]
    public fun test_cancel_listing(
        dev: &signer,
        token_seller: &signer,
        token_buyer: &signer,
        aptos_framework: &signer
    ) acquires Market, TokenStoreEscrow, TokenListings {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        account::create_account_for_test(signer::address_of(dev));
        initialize_market(dev, signer::address_of(dev), signer::address_of(dev), 0, false);
        account::create_account_for_test(signer::address_of(token_seller));
        let _ = token::create_collection_and_token(
            token_seller,
            100,
            100,
            100,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );
        account::create_account_for_test(signer::address_of(token_buyer));
        token::initialize_token_store(token_buyer);
        coin::create_fake_money(token_buyer, token_seller, 100);

        add_coin_type_to_whitelist<coin::FakeMoney>(dev);
        create_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
            100,
            1,
            0,
        );
        timestamp::update_global_time_for_test(15000000);
        // token owner cancel listing of remaining tokens
        cancel_sale<coin::FakeMoney>(
            token_seller,
            signer::address_of(token_seller),
            token::get_collection_name(),
            token::get_token_name(),
            0,
        );
    }
}
